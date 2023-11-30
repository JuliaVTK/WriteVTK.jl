using HDF5

abstract type VTKFileType end 
struct VTKHDF5 <: VTKFileType end
struct VTKXML <: VTKFileType end

struct VTKHDFUnstructuredGrid <: UnstructuredVTKDataset end

struct VTKHDF5File <: VTKFile 
    h5file # an HDF5.File
    version::AbstractString
    grid_type::AbstractString
    Npts::Int
    Ncls::Int
end

function vtk_grid(
    ::VTKHDF5,
    filename,
    points, 
    cells;
    kws...
)
    vtk_grid(
        VTKHDFUnstructuredGrid(),
        filename, points, cells; kws...)
end

function vtk_grid(
    dtype::VTKHDFUnstructuredGrid, 
    filename::AbstractString,
    points::UnstructuredCoords, 
    cells::CellVector;
    kwargs...)

    Npts = num_points(dtype, points)
    Ncls = length(cells)

    # vtk cell information
    IntType = connectivity_type(cells) :: Type{<:Integer}
    # Create data arrays.
    offsets = Array{IntType}(undef, Ncls+1)
    offsets[1] = 0

    types = Array{UInt8}(undef, Ncls)

    Nconn = 0     # length of the connectivity array
    if Ncls >= 1  # it IS possible to have no cells
        offsets[2] = length(cells[1].connectivity)
    end
    
    for (n, c) in enumerate(cells)
        Npts_cell = length(c.connectivity)
        Nconn += Npts_cell
        types[n] = cell_type(c).vtk_id
        if n >= 2
            offsets[n+1] = offsets[n] + Npts_cell
        end
    end
    display(offsets)

    # Create connectivity array.
    conn = Array{IntType}(undef, Nconn)
    n = 1
    for c in cells, i in c.connectivity
        # We transform to zero-based indexing, required by VTK.
        conn[n] = i - one(i)
        n += 1
    end

    h5file = h5open("$filename.vtkhdf", "w")

    # write attributes
    VTKHDF_group = create_group(h5file, "VTKHDF")
    HDF5.attributes(VTKHDF_group)["Version"] = [2, 0]

	type = "UnstructuredGrid"
    h5_dspace = HDF5.dataspace(type)
    h5_dtype = HDF5.datatype(type)
    HDF5.h5t_set_cset(h5_dtype, HDF5.H5T_CSET_ASCII)
    attr = create_attribute(VTKHDF_group, "Type", h5_dtype, h5_dspace)
    write_attribute(attr, h5_dtype, type)

	VTKHDF_group["NumberOfConnectivityIds"] = [Nconn]
    VTKHDF_group["NumberOfPoints"] = [Npts]
    VTKHDF_group["NumberOfCells"] = [Ncls]
    VTKHDF_group["Points"] = points
    VTKHDF_group["Types"] = types
    VTKHDF_group["Connectivity"] = conn
    VTKHDF_group["Offsets"] = offsets

    VTKHDF5File(h5file, "2.0", type, Npts, Ncls)
end

# check if file is open
Base.isopen(file::VTKHDF5File) = isopen(file.h5file)

function Base.close(file::VTKHDF5File)
    if isopen(file)
        close(file.h5file)
    end
end
