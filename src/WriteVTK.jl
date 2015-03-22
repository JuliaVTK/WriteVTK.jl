module WriteVTK

# TODO
# - Write some documentation!!
# - Add better support for 2D datasets (slices).
# - Reduce duplicate code: data_to_xml() variants...
# - Generalise:
#   * add support for other types of grid (RectilinearGrid should be easy).
#   * add support for cell data (not sure if this is easy though...).
# - Allow AbstractArray types.
#   NOTE: using SubArrays/ArrayViews can be significantly slower!!

export VTKFile, MultiblockFile, DatasetFile
export vtk_multiblock, vtk_grid, vtk_save, vtk_point_data

using LightXML
import Zlib

# Use @compat macro to solve compatibility problems between Julia 0.3 and 0.4.
# For example, the way of defining Dicts in 0.3 is deprecated in 0.4.
using Compat

# ====================================================================== #
## Constants ##
const COMPRESSION_LEVEL = 6
const APPEND = true         # FIXME this constant is temporary...

# ====================================================================== #
## Types ##
abstract VTKFile

type DatasetFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    compressed::Bool
    Npts::Int           # Number of grid points (= Nx*Ny*Nz).
    buf::IOBuffer       # Buffer with appended data.

    # Override default constructor.
    DatasetFile(xdoc, path, compressed, Npts) =
        new(xdoc, path, compressed, Npts, IOBuffer())
end

type MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    blocks::Vector{VTKFile}

    # Override default constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

# ====================================================================== #
## Functions ##

function vtk_multiblock(filename_noext::String)
    # Initialise VTK multiblock file (extension .vtm).
    # filename_noext: filename without the extension (.vtm).

    xvtm = XMLDocument()
    xroot = create_root(xvtm, "VTKFile")
    atts = @compat Dict{String,String}(
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
    atts = @compat Dict{String,String}("index" => "0", "file" => fname)
    set_attributes(xDataSet, atts)

    # -------------------------------------------------- #
    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    return
end

function data_to_xml{T<:FloatingPoint}(
    bapp::IOBuffer, xParent::XMLElement, data::Array{T}, Nc::Integer,
    varname::String, compress::Bool)
    # This variant of data_to_xml should be used when writing appended data.
    # * bapp is the IOBuffer where the appended data is written.
    # * xParent is the XML node under which the DataArray node will be created.
    #   It is either a "Points" or a "PointData" node.

    @assert name(xParent) in ("Points", "PointData")

    if T === Float32
        sType = "Float32"
    elseif T === Float64
        sType = "Float64"
    else
        error("FloatingPoint subtype not supported: $T")
    end

    # -------------------------------------------------- #
    # DataArray node
    xDA = new_child(xParent, "DataArray")
    atts = @compat Dict{String,String}(
        "type"               => sType,
        "Name"               => varname,
        "NumberOfComponents" => "$Nc",
        "format"             => "appended",
        "offset"             => "$(bapp.size)")
    set_attributes(xDA, atts)

    # Number of bytes of data.
    nb = uint32(sizeof(data))

    # Write raw binary data to an IOBuffer, and then to "bapp".
    # NOTE: I can't write directly to the "bapp" buffer, since I first need to
    # know the size of the compressed data, to be included in the header.
    buf = IOBuffer()

    if compress
        zWriter = Zlib.Writer(buf, COMPRESSION_LEVEL)
        io = zWriter
    else
        io = buf
        write(io, nb)       # header (uncompressed version)
    end

    write(io, data)

    if compress
        # Header (Uint32 values):
        #   num_blocks | blocksize | last_blocksize | compressed_blocksizes
        #
        # See:
        #   http://public.kitware.com/pipermail/paraview/2005-April/001391.html
        #   http://mathema.tician.de/what-they-dont-tell-you-about-vtk-xml-binary-formats
        close(zWriter)
        hdr = uint32([1, nb, nb, buf.size])
        write(bapp, hdr)
    end

    write(bapp, takebuf_array(buf))

    close(buf)

    return xDA
end

function data_to_xml{T<:FloatingPoint}(
    xParent::XMLElement, data::Array{T}, Nc::Integer, varname::String,
    compress::Bool)
    # This variant of data_to_xml should be used when writing data "inline" into
    # the XML file (not appended at the end).
    # * xParent is the XML node under which the DataArray node will be created.
    #   It is either a "Points" or a "PointData" node.

    @assert name(xParent) in ("Points", "PointData")

    if T === Float32
        sType = "Float32"
    elseif T === Float64
        sType = "Float64"
    else
        error("FloatingPoint subtype not supported: $T")
    end

    # -------------------------------------------------- #
    # DataArray node
    xDA = new_child(xParent, "DataArray")
    atts = @compat Dict{String,String}(
        "type"               => sType,
        "Name"               => varname,
        "NumberOfComponents" => "$Nc",
        "format"             => "binary")
    set_attributes(xDA, atts)

    # Number of bytes of data.
    nb = uint32(sizeof(data))

    # Write data to an IOBuffer, which is then base64-encoded and added to the
    # XML document.
    buf = IOBuffer()

    if compress
        zWriter = Zlib.Writer(buf, COMPRESSION_LEVEL)
        io = zWriter
    else
        io = buf
        write(io, nb)       # header (uncompressed version)
    end

    write(io, data)

    add_text(xDA, "\n")

    if compress
        close(zWriter)
        hdr = uint32([1, nb, nb, buf.size])
        add_text(xDA, base64(hdr))
    end

    add_text(xDA, base64(takebuf_string(buf)))
    add_text(xDA, "\n")

    close(buf)

    return xDA
end

function vtk_grid{T<:FloatingPoint}(
    vtm::MultiblockFile, x::Array{T}, y::Array{T}, z::Array{T};
    compress::Bool=true)
    #==========================================================================#
    # Creates a new grid file with coordinates x, y, z; and this file is
    # referenced as a block in the vtm file.
    #==========================================================================#

    # vtm file without the extension
    path_base = splitext(vtm.path)[1]

    # vts file without the extension
    vtsFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))

    vts = vtk_grid(vtsFilename_noext, x, y, z, compress=compress)

    multiblock_add_block(vtm, vts)

    return vts
end

function vtk_grid{T<:FloatingPoint}(
    filename_noext::String, x::Array{T,3}, y::Array{T,3}, z::Array{T,3};
    compress::Bool=true)
    #==========================================================================#
    # Creates a new grid file with coordinates x, y, z.
    #
    # The saved file has the name given by filename_noext, and its extension
    # depends on the type of grid.
    # For now, only StructuredGrid (.vts) is supported.
    #
    # TODO
    # - Support RectilinearGrid (.vtr).
    #   For RectilinearGrid: create variant of vtk_grid that accepts 1-dimension
    #   arrays instead of 3D (for example, x::Array{T,1}).
    #
    #==========================================================================#

    @assert size(x) == size(y) == size(z)
    Nx, Ny, Nz = size(x)

    xvts = XMLDocument()

    vts = DatasetFile(xvts, "$(filename_noext).vts", compress, Nx*Ny*Nz)

    # -------------------------------------------------- #
    # VTKFile node
    xroot = create_root(xvts, "VTKFile")

    atts = @compat Dict{String,String}(
        "type"       => "StructuredGrid",
        "version"    => "1.0",
        "byte_order" => "LittleEndian")

    if vts.compressed
        atts["compressor"] = "vtkZLibDataCompressor"
        atts["header_type"] = "UInt32"
    end

    set_attributes(xroot, atts)

    # -------------------------------------------------- #
    # StructuredGrid node
    xSG = new_child(xroot, "StructuredGrid")
    extent = "1 $Nx 1 $Ny 1 $Nz"
    set_attribute(xSG, "WholeExtent", extent)

    # -------------------------------------------------- #
    # Piece node
    xPiece = new_child(xSG, "Piece")
    set_attribute(xPiece, "Extent", extent)

    # -------------------------------------------------- #
    # Points node
    xPoints = new_child(xPiece, "Points")

    # -------------------------------------------------- #
    # DataArray node
    xyz = [x[:] y[:] z[:]]'         # shape: [3, Nx*Ny*Nz]

    if APPEND
        xDA = data_to_xml(vts.buf, xPoints, xyz, 3, "Points", vts.compressed)
    else
        xDA = data_to_xml(xPoints, xyz, 3, "Points", vts.compressed)
    end

    return vts
end

function vtk_point_data{T<:FloatingPoint}(
    vtk::DatasetFile, data::Array{T}, name::String)
    #==================================================
    # Accepted shapes of data:
    #
    #   Scalar          data[1:Nx, 1:Ny, 1:Nz]
    #                   data[1:Npts]
    #
    #   Vector          data[1:Nc, 1:Nx, 1:Ny, 1:Nz]
    #   (Nc <= 3)       data[1:Nc, 1:Npts]
    ==================================================#

    # Number of components.
    Nc = div(length(data), vtk.Npts)

    @assert Nc*vtk.Npts == length(data)

    if Nc > 3
        error("Too many components: $Nc")
    end

    # -------------------------------------------------- #
    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, "StructuredGrid")   # TODO generalise...
    xPiece = find_element(xGrid, "Piece")

    # Find or create PointData node.
    xtmp = find_element(xPiece, "PointData")
    xPD = (xtmp === nothing) ? new_child(xPiece, "PointData") : xtmp

    # -------------------------------------------------- #
    # DataArray node
    if APPEND
        xDA = data_to_xml(vtk.buf, xPD, data, Nc, name, vtk.compressed)
    else
        xDA = data_to_xml(xPD, data, Nc, name, vtk.compressed)
    end

    return
end

function vtk_save(vtm::MultiblockFile)
    # Saves VTK multiblock file (.vtm).
    # Also saves the contained block files (vtm.blocks) recursively.

    for vtk in vtm.blocks
        vtk_save(vtk)
    end

    save_file(vtm.xdoc, vtm.path)

    return vtm.path::String
end

function vtk_save(vtk::DatasetFile)
    if !APPEND
        close(vtk.buf)  # Close append buffer, even if it wasn't used.
        save_file(vtk.xdoc, vtk.path)
        return vtk.path::String
    end

    ## if APPEND:
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

    return vtk.path::String
end

end     # module WriteVTK
