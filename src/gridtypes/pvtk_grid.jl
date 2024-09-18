# Helper types

struct PVTKArgs
    part::Int
    nparts::Int
    ismain::Bool
    ghost_level::Int
end

struct PVTKFile <: VTKFile
    pvtkargs::PVTKArgs
    xdoc::XMLDocument
    vtk::DatasetFile
    path::String
    function PVTKFile(args, xdoc, vtk, path)
        finalizer(LightXML.free, xdoc)
        new(args, xdoc, vtk, path)
    end
end

# This is just to make a PVTKFile work like a DatasetFile.
# Only used when writing VTKFieldData to a PVTK file.
# Note that data is always written as text (ASCII).
data_format(::PVTKFile) = :ascii

# Returns true if the arguments do *not* contain any cell vectors.
_pvtk_is_structured(x::AbstractVector{<:AbstractMeshCell}, args...) = Val(false)
_pvtk_is_structured(x, args...) = _pvtk_is_structured(args...)
_pvtk_is_structured() = Val(true)

_pvtk_nparts(structured::Val{false}; nparts::Integer, etc...) = nparts
_pvtk_nparts(structured::Val{true}; extents::AbstractArray, etc...) = length(extents)

_pvtk_extents(structured::Val{false}; etc...) = nothing
_pvtk_extents(structured::Val{true}; extents::AbstractArray, etc...) = extents

# Filter keyword arguments to be passed to vtk_grid.
_remove_parallel_kwargs(; nparts = nothing, extents = nothing, kws...) =
    NamedTuple(kws)

# Determine whole extent from the local extents associated to each process.
function compute_whole_extent(extents::AbstractArray{<:Extent})
    # Compute the minimum and maximum across each dimension
    begins = mapreduce(ext -> map(first, ext), min, extents)
    ends = mapreduce(ext -> map(last, ext), max, extents)
    map((b, e) -> b:e, begins, ends)
end

compute_whole_extent(::Nothing) = nothing

"""
    pvtk_grid(
        filename, args...;
        part, nparts, extents, ismain = (part == 1), ghost_level = 0,
        kwargs...,
    )

Returns a handler representing a parallel VTK file, which can be
eventually written to file with [`close`](@ref).

Positional and keyword arguments in `args` and `kwargs` are passed to [`vtk_grid`](@ref)
verbatim.
Note that serial filenames are automatically generated from `filename` and from
the process id `part`.

The following keyword arguments only apply to parallel VTK file formats.

Mandatory ones are:

- `part`: current (1-based) part id,
- `nparts`: total number of parts (only required for **unstructured** grids),
- `extents`: array specifying the partitioning of a **structured** grid across
  different processes (see below for details).

Optional ones are:

- `ismain`: `true` if the current part id `part` is the main (the only one that will write the `.pvtk` file),
- `ghost_level`: ghost level.

## Specifying extents for a structured grid

For structured grids, the partitioning of the dataset across different processes
must be specified via the `extents` argument.
This is an array where each element represents the data extent associated to a
given process.

For example, for a dataset of global dimensions ``15×12×4`` distributed across 4
processes, this array may look like the following:

```julia
extents = [
    ( 1:10,  1:5, 1:4),  # process 1
    (10:15,  1:5, 1:4),  # process 2
    ( 1:10, 5:12, 1:4),  # process 3
    (10:15, 5:12, 1:4),  # process 4
]
```

Some important notes:

- the `extents` argument must be the same for all processes;
- the extents **must overlap**, or VTK / ParaView will complain when trying to
  open the files;
- the length of the `extents` array gives the number of processes.
  Therefore, the `nparts` argument is redundant and does not need to be passed.

"""
function pvtk_grid(
        filename::AbstractString, args...;
        part, ismain = (part == 1), ghost_level = 0, kwargs...,
    )
    is_structured = _pvtk_is_structured(args...)
    nparts = _pvtk_nparts(is_structured; kwargs...)
    extents = _pvtk_extents(is_structured; kwargs...)

    prefix = _pvtk_vtk_filename_prefix(filename; relative_to_pvtk = false, create_dirs = true)
    filename_serial = _serial_filename(part, nparts, prefix, "")

    vtk = let kws_vtk = _remove_parallel_kwargs(; kwargs...)
        kws = if extents === nothing
            kws_vtk
        else
            (; kws_vtk..., extent = extents[part])
        end
        vtk_grid(filename_serial, args...; kws...)
    end

    pvtkargs = PVTKArgs(part, nparts, ismain, ghost_level)
    xdoc = XMLDocument()
    _, ext = splitext(vtk.path)
    path = filename * ".p" * ext[2:end]
    pvtk = PVTKFile(pvtkargs, xdoc, vtk, path)
    _init_pvtk!(pvtk, extents)

    pvtk
end

# Add point and cell data as usual
function Base.setindex!(
        pvtk::PVTKFile, data, name::AbstractString, loc::AbstractFieldData,
    )
    pvtk.vtk[name, loc] = data
end

# In the case of field data, also add it to the pvtk file.
# Otherwise field data (typically the time / "TimeValue") is not seen by ParaView.
function Base.setindex!(
        pvtk::PVTKFile, data, name::AbstractString, loc::VTKFieldData,
    )
    pvtk.vtk[name, loc] = data
    if pvtk.pvtkargs.ismain
        add_field_data(pvtk, data, name, loc)
    end
    data
end

# Used in add_field_data.
# We need to find the PUnstructuredGrid / PStructuredGrid / ... node.
function find_base_xml_node_to_add_field(pvtk::PVTKFile, loc)
    xroot = root(pvtk.xdoc)
    pgrid_type = "P" * pvtk.vtk.grid_type
    find_element(xroot, pgrid_type)
end

# If `loc` was not passed, try to guess which kind of data was passed.
function Base.setindex!(
        pvtk::PVTKFile, data, name::AbstractString,
    )
    loc = guess_data_location(data, pvtk.vtk) :: AbstractFieldData
    pvtk[name, loc] = data
end

# Write XML attribute.
# Example:
#
#   pvtk[VTKCellData()] = Dict("HigherOrderDegrees" => "HigherOrderDegreesDataset")
#
function Base.setindex!(
        pvtk::PVTKFile, attributes, loc::AbstractFieldData,
    )
    pvtk.vtk[loc] = attributes
end

# Save as usual
function vtk_save(pvtk::PVTKFile)
    outfiles = String[]
    if isopen(pvtk)
        if pvtk.pvtkargs.ismain
            _update_pvtk!(pvtk)
            save_file(pvtk.xdoc, pvtk.path)
            push!(outfiles, pvtk.path)
        end
        append!(outfiles, close(pvtk.vtk))
        close_xml(pvtk)
    end
    outfiles
end

# Helper functions
function _serial_filename(part, nparts, prefix, extension)
    p = lpad(part, ndigits(nparts), '0')
    prefix * "_$p" * extension
end

# Determine base filename (or "prefix") for serial VTK files included in a parallel VTK
# file.
# Here `path` is the basename of the main pvtk file (without the extension).
# Note that it can be in a subdirectory of `.`, and it can either be an absolute or relative
# path.
# If it is an absolute value, then always return an absolute value.
function _pvtk_vtk_filename_prefix(path; relative_to_pvtk, create_dirs = false)
    dir_serial = path  # directory where serial files will be written
    if create_dirs
        mkpath(dir_serial)
    end
    bname = basename(path)
    if isabspath(path) || !relative_to_pvtk
        joinpath(dir_serial, bname)
    else
        _, reldir = splitdir(dir_serial)
        joinpath(reldir, bname)
    end
end

function _init_pvtk!(pvtk::PVTKFile, extents)
    # Recover some data
    vtk = pvtk.vtk
    pvtkargs = pvtk.pvtkargs
    pgrid_type = "P" * vtk.grid_type
    npieces = pvtkargs.nparts
    pref, _ = splitext(pvtk.path)
    _, ext = splitext(vtk.path)
    prefix = _pvtk_vtk_filename_prefix(pref; relative_to_pvtk = true)

    # VTKFile (root) node
    pvtk_root = create_root(pvtk.xdoc, "VTKFile")
    set_attribute(pvtk_root, "type", pgrid_type)
    set_attribute(pvtk_root, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(pvtk_root, "byte_order", "LittleEndian")
    else
        set_attribute(pvtk_root, "byte_order", "BigEndian")
    end

    # Grid node
    pvtk_grid = new_child(pvtk_root, pgrid_type)
    set_attribute(pvtk_grid, "GhostLevel", string(pvtkargs.ghost_level))

    # Pieces (i.e. Pointers to serial files)
    for piece ∈ 1:npieces
        pvtk_piece = new_child(pvtk_grid, "Piece")
        fn = _serial_filename(piece, npieces, prefix, ext)
        set_attribute(pvtk_piece, "Source", fn)

        # Add local extent if necessary
        if extents !== nothing
            set_attribute(pvtk_piece, "Extent", extent_attribute(extents[piece]))
        end
    end

    # Add whole extent if necessary
    whole_extent = compute_whole_extent(extents)
    if whole_extent !== nothing
        set_attribute(pvtk_grid, "WholeExtent", extent_attribute(whole_extent))
    end

    # Getting original grid informations
    # Recover point type and number of components
    vtk_root = root(vtk.xdoc)
    vtk_grid = find_element(vtk_root, vtk.grid_type)

    # adding origin and spacing if necessary
    origin = attribute(vtk_grid, "Origin")
    if origin !== nothing
        set_attribute(pvtk_grid, "Origin", origin)
    end

    spacing = attribute(vtk_grid, "Spacing")
    if spacing !== nothing
        set_attribute(pvtk_grid, "Spacing", spacing)
    end

    # Getting original piece informations
    vtk_piece = find_element(vtk_grid, "Piece")

    # If serial VTK has points
    vtk_points = find_element(vtk_piece, "Points")
    if vtk_points !== nothing
        vtk_data_array = find_element(vtk_points, "DataArray")
        point_type = attribute(vtk_data_array, "type")
        Nc = attribute(vtk_data_array, "NumberOfComponents")
        ## PPoints node
        pvtk_ppoints = new_child(pvtk_grid, "PPoints")
        pvtk_pdata_array = new_child(pvtk_ppoints, "PDataArray")
        set_attribute(pvtk_pdata_array, "type", point_type)
        set_attribute(pvtk_pdata_array, "Name", "Points")
        set_attribute(pvtk_pdata_array, "NumberOfComponents", Nc)
    end

    # If serial VTK has coordinates
    vtk_coordinates = find_element(vtk_piece, "Coordinates")
    if vtk_coordinates !== nothing
        pvtk_pcoordinates = new_child(pvtk_grid, "PCoordinates")
        for c in child_elements(vtk_coordinates)
            pvtk_pdata_array = new_child(pvtk_pcoordinates, "PDataArray")
            set_attribute(pvtk_pdata_array, "type", attribute(c, "type"))
            set_attribute(pvtk_pdata_array, "Name", attribute(c, "Name"))
            set_attribute(pvtk_pdata_array, "NumberOfComponents", attribute(c, "NumberOfComponents"))
        end
    end

    pvtk
end

function _update_pvtk!(pvtk::PVTKFile)
    vtk = pvtk.vtk
    vtk_root = root(vtk.xdoc)
    vtk_grid = find_element(vtk_root, vtk.grid_type)
    vtk_piece = find_element(vtk_grid, "Piece")

    pgrid_type = "P" * vtk.grid_type
    pvtk_root = root(pvtk.xdoc)
    pvtk_grid = find_element(pvtk_root, pgrid_type)

    # Generate PPointData
    vtk_point_data = find_element(vtk_piece, "PointData")
    if vtk_point_data !== nothing
        pvtk_ppoint_data = new_child(pvtk_grid, "PPointData")
        for a in attributes(vtk_point_data)
            set_attribute(pvtk_ppoint_data, name(a), value(a))
        end
        for vtk_data_array in child_elements(vtk_point_data)
            t = attribute(vtk_data_array, "type")
            name = attribute(vtk_data_array, "Name")
            Nc = attribute(vtk_data_array, "NumberOfComponents")
            pvtk_pdata_array = new_child(pvtk_ppoint_data, "PDataArray")
            set_attribute(pvtk_pdata_array, "type", t)
            set_attribute(pvtk_pdata_array, "Name", name)
            set_attribute(pvtk_pdata_array, "NumberOfComponents", Nc)
        end
    end

    # Generate PCellData
    vtk_cell_data = find_element(vtk_piece, "CellData")
    if vtk_cell_data !== nothing
        pvtk_pcell_data = new_child(pvtk_grid, "PCellData")
        for a in attributes(vtk_cell_data)
            set_attribute(pvtk_pcell_data, name(a), value(a))
        end
        for vtk_data_array in child_elements(vtk_cell_data)
            t = attribute(vtk_data_array, "type")
            name = attribute(vtk_data_array, "Name")
            Nc = attribute(vtk_data_array, "NumberOfComponents")
            pvtk_pdata_array = new_child(pvtk_pcell_data, "PDataArray")
            set_attribute(pvtk_pdata_array, "type", t)
            set_attribute(pvtk_pdata_array, "Name", name)
            set_attribute(pvtk_pdata_array, "NumberOfComponents", Nc)
        end
    end

    pvtk
end
