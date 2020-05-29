# Numerical data may be associated either to grid points or to cells.
struct VTKPointData end
struct VTKCellData end

const DataLocation = Union{VTKPointData, VTKCellData}

# These are the VTK names associated to each data "location".
node_type(::VTKPointData) = "PointData"
node_type(::VTKCellData) = "CellData"

"""
    InputDataType

Types allowed as input to `setindex!(vtk, ...)`, `vtk_point_data()` and
`vtk_cell_data()`.

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
        throw(ArgumentError("incorrect dimensions of input array."))
    end
    Nc
end

num_components(data::AbstractArray, vtk::DatasetFile, ::VTKPointData) =
    num_components(data, vtk.Npts)

num_components(data::AbstractArray, vtk::DatasetFile, ::VTKCellData) =
    num_components(data, vtk.Ncls)

num_components(data::NTuple, args...) = length(data)

# Guess from data dimensions whether data should be associated to points or
# cells.
function guess_data_location(data::AbstractArray,
                             vtk::DatasetFile) :: DataLocation
    N = length(data)
    if rem(N, vtk.Npts) == 0
        return VTKPointData()
    elseif rem(N, vtk.Ncls) == 0
        return VTKCellData()
    end
    throw(ArgumentError(
        "data dimensions are not compatible with geometry dimensions"))
end

guess_data_location(data::NTuple, args...) =
    guess_data_location(first(data), args...)

guess_data_location(data::NTuple{0}, args...) = VTKPointData()

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
    throw(ArgumentError("data type not supported by VTK: $T"))
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
    set_attribute(xDA, "NumberOfComponents", Nc)
    set_attribute(xDA, "format", "appended")
    set_attribute(xDA, "offset", position(buf))

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
    set_attribute(xDA, "NumberOfComponents", Nc)
    set_attribute(xDA, "format", "binary")   # here, binary means base64-encoded

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
"""
function vtk_point_or_cell_data(vtk::DatasetFile, data::InputDataType,
                                name::AbstractString, loc::DataLocation)
    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, vtk.grid_type)
    xPiece = find_element(xGrid, "Piece")

    # Find or create "nodetype" (PointData or CellData) node.
    nodetype = node_type(loc)
    xtmp = find_element(xPiece, nodetype)
    xPD = (xtmp === nothing) ? new_child(xPiece, nodetype) : xtmp

    # DataArray node
    Nc = num_components(data, vtk, loc)
    xDA = data_to_xml(vtk, xPD, data, name, Nc)

    vtk
end

vtk_point_data(vtk::DatasetFile, data::InputDataType, name::AbstractString) =
    vtk_point_or_cell_data(vtk, data, name, VTKPointData())

vtk_cell_data(vtk::DatasetFile, data::InputDataType, name::AbstractString) =
    vtk_point_or_cell_data(vtk, data, name, VTKCellData())

"""
    setindex!(vtk::DatasetFile, data, name::AbstractString, [location])

Add a new dataset to VTK file.

The number of components of the dataset (e.g. for scalar or vector fields) is
determined automatically from the input data dimensions.

The optional argument `location` must be an instance of `VTKPointData` or
`VTKCellData`, and determines whether the data should be associated to grid
points or cells. If not given, this is determined automatically from the input
data dimensions.

# Example

Add "velocity" dataset to VTK file.

```julia
vel = rand(3, 12, 14, 42)  # vector field
vtk = vtk_grid(...)
vtk["velocity", VTKPointData()] = vel

# This should also work, and will generally give the same result:
vtk["velocity"] = vel
```

"""
Base.setindex!(vtk::DatasetFile, data::InputDataType, name::AbstractString,
               loc::DataLocation) = vtk_point_or_cell_data(vtk, data, name, loc)

function Base.setindex!(vtk::DatasetFile, data::InputDataType,
                        name::AbstractString)
    loc = guess_data_location(data, vtk) :: DataLocation
    setindex!(vtk, data, name, loc)
end
