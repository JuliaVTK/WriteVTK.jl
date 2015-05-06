module WriteVTK

# TODO
# - Add better support for 2D datasets (slices).
# - Reduce duplicate code: data_to_xml() variants...
# - Allow AbstractArray types.
#   NOTE: using SubArrays/ArrayViews can be significantly slower!!
# - Add tests for non-default cases (append=false, compress=false in vtk_grid).
# - Add MeshCell constructors for common cell types (triangles, quads,
#   tetrahedrons, hexahedrons, ...).
#   That stuff should probably be included in a separate file.
# - Point definition between structured and unstructured grids is inconsistent!!
#   (There's no reason why their definitions should be different...)
# - It's probably better to break vtk_grid into functions for each grid type.
#   (The name doesn't need to change though!)
#   Right now, I'm not really sure why I'm not getting errors because of
#   ambiguity of function definitions...

# All the code is based on the VTK file specification [1], plus some
# undocumented stuff found around the internet...
# [1] http://www.vtk.org/VTK/img/file-formats.pdf

export VTKCellType
export MeshCell
export vtk_multiblock, vtk_grid, vtk_save, vtk_point_data, vtk_cell_data

using LightXML
import Zlib

using Compat

# More compatibility with Julia 0.3.
if VERSION < v"0.4-"
    const base64encode = base64::Function
end

# Cell type definitions as in vtkCellType.h
include("VTKCellType.jl")

# ====================================================================== #
## Constants ##
const COMPRESSION_LEVEL = 6

# Grid types (maybe there's a better way of doing this?).
const GRID_RECTILINEAR  = 1
const GRID_STRUCTURED   = 2
const GRID_UNSTRUCTURED = 3

# ====================================================================== #
## Types ##
abstract VTKFile

immutable DatasetFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    gridType::Int       # One of the GRID_* constants.
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    Ncls::Int           # Number of cells.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (or written inline, base64-encoded?)
    buf::IOBuffer       # Buffer with appended data.

    # Override default constructor.
    function DatasetFile(xdoc, path, gridType, Npts, Ncls, compressed, appended)
        gridType_str =
            gridType == GRID_RECTILINEAR  ?  "RectilinearGrid" :
            gridType == GRID_STRUCTURED   ?   "StructuredGrid" :
            gridType == GRID_UNSTRUCTURED ? "UnstructuredGrid" :
            error("Grid type not supported...")

        if appended
            buf = IOBuffer()
        else
            # In this case we don't need a buffer, so just use a closed one.
            buf = IOBuffer(0)
            close(buf)
        end

        # Number of cells should be different than zero only for unstructured
        # meshes.
        @assert gridType == GRID_UNSTRUCTURED || Ncls == 0

        return new(xdoc, path, gridType, gridType_str, Npts, Ncls, compressed,
                   appended, buf)
    end
end

immutable MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    blocks::Vector{VTKFile}

    # Override default constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

# Cells in unstructured meshes.
immutable MeshCell
    ctype::UInt8                 # cell type identifier (see vtkCellType.jl)
    connectivity::Vector{Int32}  # indices of points (one-based, like in Julia!!)
end

# ====================================================================== #
## Functions ##

function vtk_multiblock(filename_noext::AbstractString)
    # Initialise VTK multiblock file (extension .vtm).
    # filename_noext: filename without the extension (.vtm).

    xvtm = XMLDocument()
    xroot = create_root(xvtm, "VTKFile")
    atts = @compat Dict{UTF8String,UTF8String}(
        "type"       => "vtkMultiBlockDataSet",
        "version"    => "1.0",
        "byte_order" => "LittleEndian")
    set_attributes(xroot, atts)

    xMBDS = new_child(xroot, "vtkMultiBlockDataSet")

    return MultiblockFile(xvtm, string(filename_noext, ".vtm"))
end

function multiblock_add_block(vtm::MultiblockFile, vtk::VTKFile)
    # Add VTK file as a new block to a multiblock file.

    # -------------------------------------------------- #
    xroot = root(vtm.xdoc)
    xMBDS = find_element(xroot, "vtkMultiBlockDataSet")

    # -------------------------------------------------- #
    # Block node
    xBlock = new_child(xMBDS, "Block")
    nblock = length(vtm.blocks)
    set_attribute(xBlock, "index", "$nblock")

    # -------------------------------------------------- #
    # DataSet node
    # This splits the filename and the directory name.
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(xBlock, "DataSet")
    atts = @compat Dict{UTF8String,UTF8String}(
                        "index" => "0", "file" => fname)
    set_attributes(xDataSet, atts)

    # -------------------------------------------------- #
    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    return
end

function data_to_xml{T<:Real}(
    vtk::DatasetFile, xParent::XMLElement, data::Array{T}, Nc::Integer,
    varname::AbstractString)
    #==========================================================================
    This variant of data_to_xml should be used when writing appended data.
      * bapp is the IOBuffer where the appended data is written.
      * xParent is the XML node under which the DataArray node will be created.
        It is either a "Points" or a "PointData" node.

    When vtk.compressed == true:
      * the data array is written in compressed form (obviously);
      * the header, written before the actual numerical data, is an array of
        UInt32 values:
            [num_blocks, blocksize, last_blocksize, compressed_blocksizes]
        All the sizes are in bytes. The header itself is not compressed, only
        the data is.
        See also:
            http://public.kitware.com/pipermail/paraview/2005-April/001391.html
            http://mathema.tician.de/what-they-dont-tell-you-about-vtk-xml-binary-formats
      * note that VTK only allows compressing appended data, not inline data.

    Otherwise, the header is just a single UInt32 value containing the size of
    the data array in bytes.
    ==========================================================================#

    if !vtk.appended
        # Redirect to the inline version of this function.
        return data_to_xml_inline(vtk, xParent, data, Nc, varname)
    end

    const bapp = vtk.buf    # append buffer
    const compress = vtk.compressed

    @assert name(xParent) in ("Points", "PointData", "Coordinates",
                              "Cells", "CellData")

    local sType::UTF8String
    if T === Float32
        sType = "Float32"
    elseif T === Float64
        sType = "Float64"
    elseif T === Int32
        sType = "Int32"
    elseif T === UInt8
        sType = "UInt8"
    else
        error("Real subtype not supported: $T")
    end

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    atts = @compat Dict{UTF8String,UTF8String}(
        "type"               => sType,
        "Name"               => varname,
        "NumberOfComponents" => "$Nc",
        "format"             => "appended",
        "offset"             => "$(bapp.size)")
    set_attributes(xDA, atts)

    # Size of data array (in bytes).
    const nb::UInt32 = sizeof(data)

    # Position in the append buffer where the previous record ends.
    const initpos = position(bapp)
    header = zeros(UInt32, 4)

    if compress
        # Write temporary array that will be replaced later by the real header.
        write(bapp, header)

        # Write compressed data.
        zWriter = Zlib.Writer(bapp, COMPRESSION_LEVEL)
        write(zWriter, data)
        close(zWriter)

        # Write real header.
        compbytes = position(bapp) - initpos - sizeof(header)
        header[:] = [1, nb, nb, compbytes]
        seek(bapp, initpos)
        write(bapp, header)
        seekend(bapp)
    else
        write(bapp, nb)       # header (uncompressed version)
        write(bapp, data)
    end

    return xDA
end

function data_to_xml_inline{T<:Real}(
    vtk::DatasetFile, xParent::XMLElement, data::Array{T}, Nc::Integer,
    varname::AbstractString)
    #==========================================================================
    This variant of data_to_xml should be used when writing data "inline" into
    the XML file (not appended at the end).

    See the other variant of this function for more info.
    ==========================================================================#

    @assert !vtk.appended
    @assert name(xParent) in ("Points", "PointData", "Coordinates",
                              "Cells", "CellData")

    const compress = vtk.compressed

    local sType::UTF8String
    if T === Float32
        sType = "Float32"
    elseif T === Float64
        sType = "Float64"
    elseif T === Int32
        sType = "Int32"
    elseif T === UInt8
        sType = "UInt8"
    else
        error("Real subtype not supported: $T")
    end

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    atts = @compat Dict{UTF8String,UTF8String}(
        "type"               => sType,
        "Name"               => varname,
        "NumberOfComponents" => "$Nc",
        "format"             => "binary")   # here, binary means base64-encoded
    set_attributes(xDA, atts)

    # Number of bytes of data.
    const nb::UInt32 = sizeof(data)

    # Write data to an IOBuffer, which is then base64-encoded and added to the
    # XML document.
    buf = IOBuffer()

    # Position in the append buffer where the previous record ends.
    const header = zeros(UInt32, 4)     # only used when compressing

    # NOTE: in the compressed case, the header and the data need to be
    # base64-encoded separately!!
    # That's why we don't use a single buffer that contains both, like in the
    # other data_to_xml function.
    if compress
        # Write compressed data.
        zWriter = Zlib.Writer(buf, COMPRESSION_LEVEL)
        write(zWriter, data)
        close(zWriter)
    else
        write(buf, data)
    end

    # Write buffer with data to XML document.
    add_text(xDA, "\n")
    if compress
        header[:] = [1, nb, nb, buf.size]
        add_text(xDA, base64encode(header))
    else
        add_text(xDA, base64encode(nb))     # header (uncompressed version)
    end
    add_text(xDA, base64encode(takebuf_string(buf)))
    add_text(xDA, "\n")

    close(buf)

    return xDA
end

# Variant of vtk_grid for multiblock + structured (or rectilinear) grids.
function vtk_grid(vtm::MultiblockFile, x::Array, y::Array, z::Array;
                  compress::Bool=true, append::Bool=true)
    #==========================================================================#
    # Creates a new grid file with coordinates x, y, z; and this file is
    # referenced as a block in the vtm file.
    #
    # See the documentation for the other variant of vtk_grid.
    #==========================================================================#

    # Multiblock file without the extension
    path_base = splitext(vtm.path)[1]

    # Dataset file without the extension
    vtsFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtsFilename_noext, x, y, z, nothing;
                   compress=compress, append=append)
    multiblock_add_block(vtm, vtk)

    return vtk::DatasetFile
end


# Variant of vtk_grid for multiblock + unstructured grids.
function vtk_grid(vtm::MultiblockFile, points::Array, cells::Vector{MeshCell};
                  compress=true, append=true)
    path_base = splitext(vtm.path)[1]
    vtsFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtsFilename_noext, points, nothing, nothing, cells;
                   compress=compress, append=append)
    multiblock_add_block(vtm, vtk)
    return vtk::DatasetFile
end

# General vtk_grid variant, that handles all supported types of grid.
function vtk_grid{T<:FloatingPoint}(
    filename_noext::AbstractString,
    x::Array{T}, y=nothing, z=nothing, cells=nothing;
    compress::Bool=true, append::Bool=true)
    #==========================================================================#
    # Creates a new grid file with coordinates x, y, z.
    #
    # The saved file has the name given by filename_noext, and its extension
    # depends on the type of grid, which is determined by the shape of the
    # arrays x, y, z.
    #
    # Accepted grid types:
    #   * Rectilinear grid      x, y, z are 1D arrays with possibly different
    #                           lengths.
    #
    #   * Structured grid       x, y, z are 3D arrays with the same dimensions.
    #                           TODO: also allow a single "4D" array, just like
    #                           for unstructured grids, which would give a
    #                           better performance.
    #
    #   * Unstructured grid     x is an array with all the points, with
    #                           dimensions [3, num_points].
    #                           cells is a MeshCell array with all the cells.
    #
    #                           NOTE: for convenience, there's also a separate
    #                           vtk_grid function specifically made for
    #                           unstructured grids.
    #
    # Optional parameters:
    # * If compress is true, written data is first compressed using Zlib.
    #   Set to false if you don't care about file size, or if speed is really
    #   important.
    #
    # * If append is true, data is appended at the end of the XML file as raw
    #   binary data.
    #   Otherwise, data is written inline, base-64 encoded. This is usually
    #   slower than writing raw binary data, and also results in larger files.
    #   Try disabling this if there are issues (for example with portability?),
    #   or if it's really important to follow the XML specifications.
    #
    #   Note that all combinations of compress and append are supported.
    #
    #==========================================================================#

    if cells !== nothing
        @assert y === z === nothing
        @assert typeof(cells) == Vector{MeshCell}
        const grid_type = GRID_UNSTRUCTURED::Int
        const Npts::Int = div(length(x), 3)
        const Ncells = length(cells)
        const file_ext = ".vtu"
        if 3*Npts != length(x)
            error("Length of POINTS should be a multiple of 3.")
        end

    elseif length(size(x)) == 1
        @assert length(size(y)) == length(size(z)) == 1
        const grid_type = GRID_RECTILINEAR::Int
        const Ni, Nj, Nk = length(x), length(y), length(z)
        const Npts = Ni*Nj*Nk
        const Ncells = 0
        const file_ext = ".vtr"

    elseif length(size(x)) == 3
        @assert size(x) == size(y) == size(z)
        const grid_type = GRID_STRUCTURED::Int
        const Ni, Nj, Nk = size(x)
        const Npts = Ni*Nj*Nk
        const Ncells = 0
        const file_ext = ".vts"

    else
        error("Wrong dimensions of grid coordinates x, y, z.")

    end

    xvtk = XMLDocument()

    vtk = DatasetFile(xvtk, filename_noext * file_ext, grid_type, Npts, Ncells,
                      compress, append)

    # VTKFile node
    xroot = create_root(xvtk, "VTKFile")

    atts = @compat Dict{UTF8String,UTF8String}(
        "type"       => vtk.gridType_str,
        "version"    => "1.0",
        "byte_order" => "LittleEndian")

    if vtk.compressed
        atts["compressor"] = "vtkZLibDataCompressor"
        atts["header_type"] = "UInt32"
    end

    set_attributes(xroot, atts)

    # StructuredGrid node (or equivalent)
    xSG = new_child(xroot, vtk.gridType_str)
    if vtk.gridType in (GRID_RECTILINEAR, GRID_STRUCTURED)
        extent = "1 $Ni 1 $Nj 1 $Nk"
        set_attribute(xSG, "WholeExtent", extent)
    end

    # Piece node
    xPiece = new_child(xSG, "Piece")
    if vtk.gridType in (GRID_RECTILINEAR, GRID_STRUCTURED)
        set_attribute(xPiece, "Extent", extent)
    elseif vtk.gridType == GRID_UNSTRUCTURED
        set_attribute(xPiece, "NumberOfPoints", vtk.Npts)
        set_attribute(xPiece, "NumberOfCells",  vtk.Ncls)
    end

    # Points (or Coordinates) node
    if vtk.gridType in (GRID_STRUCTURED, GRID_UNSTRUCTURED)
        xPoints = new_child(xPiece, "Points")
    elseif vtk.gridType == GRID_RECTILINEAR
        xPoints = new_child(xPiece, "Coordinates")
    end

    # DataArray node
    if vtk.gridType == GRID_UNSTRUCTURED
        data_to_xml(vtk, xPoints, x, 3, "Points")

    elseif vtk.gridType == GRID_STRUCTURED
        xyz = Array(T, 3, Ni, Nj, Nk)
        for k = 1:Nk, j = 1:Nj, i = 1:Ni
            xyz[1, i, j, k] = x[i, j, k]
            xyz[2, i, j, k] = y[i, j, k]
            xyz[3, i, j, k] = z[i, j, k]
        end
        data_to_xml(vtk, xPoints, xyz, 3, "Points")

    elseif vtk.gridType == GRID_RECTILINEAR
        data_to_xml(vtk, xPoints, x, 1, "x")
        data_to_xml(vtk, xPoints, y, 1, "y")
        data_to_xml(vtk, xPoints, z, 1, "z")

    end

    # Cells node (below the Piece node)
    if vtk.gridType == GRID_UNSTRUCTURED
        xCells = new_child(xPiece, "Cells")

        # Create data arrays.
        offsets = Array(Int32, Ncells)
        types = Array(UInt8, Ncells)

        Nconn = 0   # length of the connectivity array
        offsets[1] = length(cells[1].connectivity)

        for n = 1:Ncells
            c = cells[n]
            Npts_cell = length(c.connectivity)
            Nconn += Npts_cell
            types[n] = c.ctype
            if n >= 2
                offsets[n] = offsets[n-1] + Npts_cell
            end
        end

        # Create connectivity array.
        conn = Array(Int32, Nconn)
        const ONE = one(Int32)
        n = 1
        for c in cells
            for i in c.connectivity
                # We transform to zero-based indexing, required by VTK.
                conn[n] = i - ONE
                n += 1
            end
        end

        # Add arrays to the XML file.
        data_to_xml(vtk, xCells, conn,    1, "connectivity")
        data_to_xml(vtk, xCells, offsets, 1, "offsets"     )
        data_to_xml(vtk, xCells, types,   1, "types"       )

    end     # GRID_UNSTRUCTURED

    return vtk::DatasetFile
end


# Variant of vtk_grid for unstructured meshes.
function vtk_grid{T<:FloatingPoint}(
    filename_noext::AbstractString, points::Array{T}, cells::Vector{MeshCell};
    compress::Bool=true, append::Bool=true)
    #==========================================================================#
    # Create a new unstructured grid file.
    #
    # Parameters:
    #   points      Array with the points of the mesh.
    #               Its dimensions should be [3, num_points], although
    #               "flattened" arrays are also accepted (i.e., 1-D arrays with
    #               the same array ordering).
    #
    #   cells       MeshCell array with the cell definitions.
    #               A cell is represented by a cell type (an integer value) and
    #               its connectivity, i.e., an array of indices that correspond
    #               to the cell points in the "points" array.
    #
    #               Note that the indices in the connectivity array are
    #               one-based, to be consistent with the convention in Julia.
    #
    # For details on the other arguments, see the documentation of the other
    # variants of vtk_grid.
    #
    #==========================================================================#

    return vtk_grid(filename_noext, points, nothing, nothing, cells;
                    compress=compress, append=append)
end

function vtk_point_or_cell_data{T<:FloatingPoint}(
    vtk::DatasetFile, data::Array{T}, name::AbstractString,
    nodetype::AbstractString, Nc::Int)

    # Nc: number of components (defines whether data is scalar or vectorial).
    @assert Nc in (1, 3)

    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, vtk.gridType_str)
    xPiece = find_element(xGrid, "Piece")

    # Find or create "nodetype" (PointData or CellData) node.
    xtmp = find_element(xPiece, nodetype)
    xPD = (xtmp === nothing) ? new_child(xPiece, nodetype) : xtmp

    # DataArray node
    xDA = data_to_xml(vtk, xPD, data, Nc, name)

    return
end

function vtk_point_data(vtk::DatasetFile, data::Array, name::AbstractString)
    # Number of components.
    Nc = div(length(data), vtk.Npts)
    @assert Nc*vtk.Npts == length(data)
    return vtk_point_or_cell_data(vtk, data, name, "PointData", Nc)
end

function vtk_cell_data(vtk::DatasetFile, data::Array, name::AbstractString)
    # Number of components.
    Nc = div(length(data), vtk.Ncls)
    @assert Nc*vtk.Ncls == length(data)
    return vtk_point_or_cell_data(vtk, data, name, "CellData", Nc)
end

function vtk_save(vtm::MultiblockFile)
    # Saves VTK multiblock file (.vtm).
    # Also saves the contained block files (vtm.blocks) recursively.

    outfiles = [vtm.path]::Vector{UTF8String}

    for vtk in vtm.blocks
        push!(outfiles, vtk_save(vtk)...)
    end

    save_file(vtm.xdoc, vtm.path)

    return outfiles::Vector{UTF8String}
end

function vtk_save(vtk::DatasetFile)
    if !vtk.appended
        save_file(vtk.xdoc, vtk.path)
        return [vtk.path]::Vector{UTF8String}
    end

    ## if vtk.appended:
    # Write XML file manually, including appended data.

    # NOTE: this is not very clean, but I can't write raw binary data with the
    # LightXML package.
    # Using raw data is way more efficient than base64 encoding in terms of
    # filesize AND time (especially time).

    # Convert XML document to a string, and split it by lines.
    lines = split(string(vtk.xdoc), '\n')

    # Verify that the last two lines are what they're supposed to be.
    @assert lines[end-1] == "</VTKFile>"
    @assert lines[end] == ""

    io = open(vtk.path, "w")

    # Write everything but the last two lines.
    for line in lines[1:end-2]
        write(io, line)
        write(io, "\n")
    end

    # Write raw data (contents of IOBuffer vtk.buf).
    # An underscore "_" is needed before writing appended data.
    write(io, "  <AppendedData encoding=\"raw\">")
    write(io, "\n_")
    write(io, takebuf_string(vtk.buf))
    write(io, "\n  </AppendedData>")
    write(io, "\n</VTKFile>")

    close(vtk.buf)
    close(io)

    return [vtk.path]::Vector{UTF8String}
end

end     # module WriteVTK
