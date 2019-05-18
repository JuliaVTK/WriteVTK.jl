# Contains common functions for all grid types.

"""
Types allowed as input to `vtk_point_data()` and `vtk_cell_data()`.

Either (abstract) arrays or tuples of arrays are allowed.
In the second case, the length of the tuple determines the number of components
of the input data (e.g. if N = 3, it corresponds to a 3D vector field).
"""
const InputDataType =
    Union{AbstractArray,
          NTuple{N, T} where {N, T <: AbstractArray}}

"""
Determine number of components of input data.
"""
function num_components(data::AbstractArray, num_points_or_cells::Int)
    Nc = div(length(data), num_points_or_cells)
    if Nc * num_points_or_cells != length(data)
        throw(ArgumentError("Incorrect dimensions of input array."))
    end
    Nc
end

num_components(data::NTuple, ::Int) = length(data)

"Union of data types allowed by VTK (see file-formats.pdf, page 15)."
const VTKDataType = Union{Int8, UInt8, Int16, UInt16, Int32, UInt32,
                          Int64, UInt64, Float32, Float64}

"""
Return the VTK string representation of a numerical data type.
"""
function datatype_str(::Type{T}) where T <: VTKDataType
    # Note: the VTK type names are exactly the same as the Julia type names
    # (e.g.  Float64 -> "Float64"), so that we can simply use the `string`
    # function.
    string(T)
end
datatype_str(::Type{T}) where T =
    throw(ArgumentError("Data type not supported by VTK: $T"))
datatype_str(::AbstractArray{T}) where T = datatype_str(T)
datatype_str(::NTuple{N, T} where N) where T <: AbstractArray =
    datatype_str(eltype(T))


"""
Total size of data in bytes.
"""
sizeof_data(x::Array) = sizeof(x)
sizeof_data(x::AbstractArray) = length(x) * sizeof(eltype(x))
sizeof_data(x::NTuple) = sum(sizeof_data, x)


"Write array of numerical data to stream."
function write_array(io, data::AbstractArray)
    write(io, data)
    nothing
end

function write_array(io, data::NTuple{N, T} where T <: AbstractArray) where N
    # We assume that all arrays in the tuple have the same size.
    L = length(data[1])
    for i = 1:L, x in data
        write(io, x[i])
    end
    nothing
end


"""
Add numerical data to VTK XML file.

Data is written under the `xParent` XML node.

`Nc` corresponds to the number of components of the data.
"""
function data_to_xml(vtk::DatasetFile, xParent::XMLElement, data::InputDataType,
                     varname::AbstractString, Nc::Integer=1)
    @assert name(xParent) in ("Points", "PointData", "Coordinates", "Cells",
                              "CellData")
    func :: Function = vtk.appended ? data_to_xml_appended : data_to_xml_inline
    func(vtk, xParent, data, varname, Nc) :: XMLElement
end


"""
Add appended raw binary data to VTK XML file.

Data is written to the `vtk.buf` buffer.

When compression is enabled:

  * the data array is written in compressed form (obviously);

  * the header, written before the actual numerical data, is an array of UInt32
    values:
        `[num_blocks, blocksize, last_blocksize, compressed_blocksizes]`
    All the sizes are in bytes. The header itself is not compressed, only the
    data is.
    For more details, see:
        http://public.kitware.com/pipermail/paraview/2005-April/001391.html
        http://mathema.tician.de/what-they-dont-tell-you-about-vtk-xml-binary-formats
    (This is not really documented in the VTK specification...)

Otherwise, if compression is disabled, the header is just a single UInt32 value
containing the size of the data array in bytes.

"""
function data_to_xml_appended(vtk::DatasetFile, xParent::XMLElement,
                              data::InputDataType, varname::AbstractString,
                              Nc::Integer)
    @assert vtk.appended

    buf = vtk.buf    # append buffer
    compress = vtk.compression_level > 0

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type", datatype_str(data))
    set_attribute(xDA, "Name", varname)
    set_attribute(xDA, "format", "appended")
    set_attribute(xDA, "offset", position(buf))
    set_attribute(xDA, "NumberOfComponents", string(Nc))

    # Size of data array (in bytes).
    nb = sizeof_data(data)

    if compress
        initpos = position(buf)

        # Write temporary array that will be replaced later by the real header.
        header = zeros(UInt32, 4)
        write(buf, header)

        # Write compressed data.
        zWriter = ZlibCompressorStream(buf, level=vtk.compression_level)
        write_array(zWriter, data)
        write(zWriter, TranscodingStreams.TOKEN_END)
        flush(zWriter)

        # Go back to `initpos` and write real header.
        endpos = position(buf)
        compbytes = endpos - initpos - sizeof(header)
        header[:] = [1, nb, nb, compbytes]
        seek(buf, initpos)
        write(buf, header)
        seek(buf, endpos)
    else
        write(buf, UInt32(nb))  # header (uncompressed version)
        write_array(buf, data)
    end

    xDA::XMLElement
end


"Add inline, base64-encoded data to VTK XML file."
function data_to_xml_inline(vtk::DatasetFile, xParent::XMLElement,
                            data::InputDataType, varname::AbstractString,
                            Nc::Integer)
    @assert !vtk.appended
    compress = vtk.compression_level > 0

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type", datatype_str(data))
    set_attribute(xDA, "Name", varname)
    set_attribute(xDA, "format", "binary")   # here, binary means base64-encoded
    set_attribute(xDA, "NumberOfComponents", "$Nc")

    # Number of bytes of data.
    nb = sizeof_data(data)

    # Write data to a buffer, which is then base64-encoded and added to the
    # XML document.
    buf = IOBuffer()

    # NOTE: in the compressed case, the header and the data need to be
    # base64-encoded separately!!
    # That's why we don't use a single buffer that contains both, like in the
    # other data_to_xml function.
    local zWriter
    if compress
        # Write compressed data.
        zWriter = ZlibCompressorStream(buf, level=vtk.compression_level)
        write_array(zWriter, data)
        write(zWriter, TranscodingStreams.TOKEN_END)
        flush(zWriter)
    else
        write_array(buf, data)
    end

    # Write buffer with data to XML document.
    add_text(xDA, "\n")
    if compress
        header = UInt32[1, nb, nb, position(buf)]
        add_text(xDA, base64encode(header))
    else
        add_text(xDA, base64encode(UInt32(nb)))     # header (uncompressed version)
    end
    add_text(xDA, base64encode(take!(buf)))
    add_text(xDA, "\n")

    if compress
        close(zWriter)
    end
    close(buf)

    xDA::XMLElement
end


"""
Add either point or cell data to VTK file.

Here `Nc` is the number of components of the data (Nc >= 1).
"""
function vtk_point_or_cell_data(vtk::DatasetFile, data::InputDataType,
                                name::AbstractString, nodetype::AbstractString,
                                Nc::Integer)
    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, vtk.grid_type)
    xPiece = find_element(xGrid, "Piece")

    # Find or create "nodetype" (PointData or CellData) node.
    xtmp = find_element(xPiece, nodetype)
    xPD = (xtmp === nothing) ? new_child(xPiece, nodetype) : xtmp

    # DataArray node
    xDA = data_to_xml(vtk, xPD, data, name, Nc)

    vtk
end

function vtk_point_data(vtk::DatasetFile, data::InputDataType, name::AbstractString)
    Nc = num_components(data, vtk.Npts)
    vtk_point_or_cell_data(vtk, data, name, "PointData", Nc)
end


function vtk_cell_data(vtk::DatasetFile, data::InputDataType, name::AbstractString)
    Nc = num_components(data, vtk.Ncls)
    vtk_point_or_cell_data(vtk, data, name, "CellData", Nc)
end


function vtk_save(vtk::DatasetFile)
    if isopen(vtk)
        if vtk.appended
            save_with_appended_data(vtk)
        else
            save_file(vtk.xdoc, vtk.path)
        end
        @assert isopen(vtk)
        close(vtk)
    end
    return [vtk.path] :: Vector{String}
end


"""
Write VTK XML file containing appended binary data to disk.

In this case, the XML file is written manually instead of using the `save_file`
function of `LightXML`, which doesn't allow to write raw binary data.
"""
function save_with_appended_data(vtk::DatasetFile)
    @assert vtk.appended
    @assert isopen(vtk.buf)

    # Convert XML document to a string, and split the last two lines.
    lines = rsplit(string(vtk.xdoc), '\n', limit=3, keepempty=true)

    # Verify that the last two lines are what they're supposed to be.
    @assert lines[2] == "</VTKFile>"
    @assert lines[3] == ""

    open(vtk.path, "w") do io
        # Write everything but the last two lines.
        write(io, lines[1])
        write(io, "\n")

        # Write raw data (contents of buffer vtk.buf).
        # An underscore "_" is needed before writing appended data.
        write(io, "  <AppendedData encoding=\"raw\">")
        write(io, "\n_")
        write(io, take!(vtk.buf))
        write(io, "\n  </AppendedData>")
        write(io, "\n</VTKFile>")

        close(vtk.buf)
    end

    nothing
end


function vtk_xml_write_header(vtk::DatasetFile)
    xroot = create_root(vtk.xdoc, "VTKFile")
    set_attribute(xroot, "type", vtk.grid_type)
    set_attribute(xroot, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    if vtk.compression_level > 0
        set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
        set_attribute(xroot, "header_type", "UInt32")
    end
    xroot::XMLElement
end


"""
Return the "extent" attribute required for structured (including rectilinear)
grids.
"""
extent_attribute(Ni, Nj, Nk, ::Nothing=nothing) =
    "0 $(Ni - 1) 0 $(Nj - 1) 0 $(Nk - 1)"

function extent_attribute(Ni, Nj, Nk, extent::Array{T}) where T <: Integer
    length(extent) == 6 || throw(ArgumentError("Extent must have length 6."))
    (extent[2] - extent[1] + 1 == Ni) &&
    (extent[4] - extent[3] + 1 == Nj) &&
    (extent[6] - extent[5] + 1 == Nk) ||
    throw(ArgumentError("Extent is not consistent with dataset dimensions."))
    join(extent, " ")
end


"""
Number of cells in structured grids.

In 3D, all cells are hexahedrons (i.e. VTK_HEXAHEDRON), and the number of
cells is (Ni-1)*(Nj-1)*(Nk-1). In 2D, they are quadrilaterals (VTK_QUAD), and in
1D they are line segments (VTK_LINE).
"""
function num_cells_structured(Ni, Nj, Nk)
    Ncls = one(Ni)
    for N in (Ni, Nj, Nk)
        Ncls *= max(1, N - 1)
    end
    Ncls
end
