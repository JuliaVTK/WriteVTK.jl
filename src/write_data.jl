"""
    AbstractFieldData

Abstract type representing any kind of dataset.
"""
abstract type AbstractFieldData end

# Numerical data may be associated to grid points, cells, or none.
struct VTKPointData <: AbstractFieldData end
struct VTKCellData <: AbstractFieldData end
struct VTKFieldData <: AbstractFieldData end

# These are the VTK names associated to each data "location".
node_type(::VTKPointData) = "PointData"
node_type(::VTKCellData) = "CellData"
node_type(::VTKFieldData) = "FieldData"

const ArrayOrValue = Union{AbstractArray, Number, String}
const ListOfStrings = Union{Tuple{Vararg{String}}, AbstractArray{String}}

# Determine number of components of input data.
function num_components(Ndata::Integer, num_points_or_cells)
    Nc = div(Ndata, num_points_or_cells)
    if Nc * num_points_or_cells != Ndata
        throw(DimensionMismatch("incorrect dimensions of input array."))
    end
    Nc
end

_type_length(::Type{<:Union{Number, String}}) = 1
_type_length(::Type{A}) where {A <: AbstractArray} = length(A)  # here, `A` may be a StaticArray subtype

# Returns the "length" of a single element of the array.
# This is 1 in the common case where `T <: Number`.
# However, if this is an array of StaticArrays (`T <: SArray`), then the length
# is the number of elements in each SArray.
_eltype_length(::AbstractArray{T}) where {T} = _type_length(T)
_eltype_length(::Any) = 1

num_components(data::ArrayOrValue, num_points_or_cells) =
    num_components(length(data), num_points_or_cells) * _eltype_length(data)

num_components(data::AbstractArray, vtk, ::VTKPointData) =
    num_components(data, vtk.Npts)

num_components(data::AbstractArray, vtk, ::VTKCellData) =
    num_components(data, vtk.Ncls)

num_components(data::AbstractArray, vtk, ::VTKFieldData) =
    _eltype_length(data)

num_components(::Union{Number,String}, args...) = 1
num_components(data::Tuple{Vararg{String}}, args...) = 1
num_components(data::Tuple, args...) = length(data)

# This is for the NumberOfTuples attribute of FieldData.
num_field_tuples(data::ArrayOrValue) = length(data)
num_field_tuples(data::ListOfStrings) = length(data)
num_field_tuples(data::String) = 1
num_field_tuples(data::Tuple) = num_field_tuples(first(data))

# Guess from data dimensions whether data should be associated to points,
# cells or none.
function guess_data_location(data, vtk)
    N = length(data)
    if rem(N, vtk.Npts) == 0
        VTKPointData()
    elseif rem(N, vtk.Ncls) == 0
        VTKCellData()
    else
        VTKFieldData()
    end
end

guess_data_location(data::Tuple, args...) =
    guess_data_location(first(data), args...)

guess_data_location(data::Tuple{}, args...) = VTKPointData()

"""
    VTKDataType

Union of data types allowed by VTK.
"""
const VTKDataType = Union{Int8, UInt8, Int16, UInt16, Int32, UInt32,
                          Int64, UInt64, Float32, Float64, String}

# Return the VTK string representation of a numerical data type.
function datatype_str(::Type{T}) where T <: VTKDataType
    # Note: the VTK type names are exactly the same as the Julia type names
    # (e.g.  Float64 -> "Float64"), so that we can simply use the `string`
    # function.
    string(T)
end

datatype_str(::Type{T}) where T =
    throw(ArgumentError("data type not supported by VTK: $T"))
datatype_str(v) = datatype_str(typeof(v))
datatype_str(::Type{A}) where {A <: AbstractArray} = datatype_str(eltype(A))
datatype_str(u::AbstractArray) = datatype_str(eltype(u))
datatype_str(::ListOfStrings) = datatype_str(String)

function datatype_str(t::Tuple)
    Ts = map(eltype, t)
    T = first(Ts)
    @assert all(Ts .== T)  # all elements of the tuple must have the same eltype
    datatype_str(T)
end

# Total size of data in bytes.
sizeof_data(x) = sizeof(x)
sizeof_data(x::String) = sizeof(x) + sizeof("\0")
sizeof_data(x::AbstractArray) = length(x) * sizeof(eltype(x))
sizeof_data(x::ListOfStrings) = sum(sizeof_data, x)
sizeof_data(x::Tuple) = sum(sizeof_data, x)

write_array(io, data) = write(io, data)
write_array(io, x::String) = write(io, x, '\0')
write_array(io, x::ListOfStrings) = sum(s -> write_array(io, s), x)

function write_array(io, data::Tuple)
    n = 0
    for i in eachindex(data...), x in data
        n += write(io, x[i])
    end
    n
end

function add_data_ascii(xml, x::Union{Number,String})
    add_text(xml, " ")
    add_text(xml, string(x))
end

add_data_ascii(xml, x::AbstractArray) = map(v -> add_data_ascii(xml, v), x)

function add_data_ascii(xml, data::Tuple)
    for i in eachindex(data...), x in data
        add_data_ascii(xml, x[i])
    end
end

function set_num_components(xDA, vtk, data, loc)
    Nc = num_components(data, vtk, loc)
    set_attribute(xDA, "NumberOfComponents", Nc)
    nothing
end

# In the specific case of FieldData, we also need to set the number of "tuples"
# (number of elements per field component).
function set_num_components(xDA, vtk, data, loc::VTKFieldData)
    Nc = num_components(data, vtk, loc)
    Nt = num_field_tuples(data)
    set_attribute(xDA, "NumberOfComponents", Nc)
    set_attribute(xDA, "NumberOfTuples", Nt)
    nothing
end

xml_data_array_name(::Any) = "DataArray"
xml_data_array_name(::Union{String,ListOfStrings}) = "Array"

"""
    data_to_xml(
        vtk::DatasetFile, xParent::XMLElement, data,
        name::AbstractString, Nc::Union{Int,AbstractFieldData} = 1,
    )

Add numerical data to VTK XML file.

Data is written under the `xParent` XML node.

`Nc` may be either the number of components, or the type of field data.
In the latter case, the number of components will be deduced from the data
dimensions and the type of field data.
"""
function data_to_xml(vtk, xParent, data, name,
                     Nc::Union{Int,AbstractFieldData}=1)
    xDA = new_child(xParent, xml_data_array_name(data))
    set_attribute(xDA, "type", datatype_str(data))
    set_attribute(xDA, "Name", name)
    if Nc isa Int
        set_attribute(xDA, "NumberOfComponents", Nc)
    else
        set_num_components(xDA, vtk, data, Nc)
    end
    if vtk.appended
        data_to_xml_appended(vtk, xDA, data)
    elseif vtk.ascii
        data_to_xml_ascii(vtk, xDA, data)
    else
        data_to_xml_inline(vtk, xDA, data)
    end
end

"""
    data_to_xml_appended(vtk::DatasetFile, xDA::XMLElement, data)

Add appended raw binary data to VTK XML file.

Data is written to the `vtk.buf` buffer.

When compression is enabled:

  * the data array is written in compressed form (obviously);

  * the header, written before the actual numerical data, is an array of
  HeaderType (UInt32 / UInt64) values:
        `[num_blocks, blocksize, last_blocksize, compressed_blocksizes]`
    All the sizes are in bytes. The header itself is not compressed, only the
    data is.
    For more details, see:
        http://public.kitware.com/pipermail/paraview/2005-April/001391.html
        http://mathema.tician.de/what-they-dont-tell-you-about-vtk-xml-binary-formats
    (This is not really documented in the VTK specification...)

Otherwise, if compression is disabled, the header is just a single HeaderType value
containing the size of the data array in bytes.

"""
function data_to_xml_appended(vtk::DatasetFile, xDA::XMLElement, data)
    @assert vtk.appended

    buf = vtk.buf    # append buffer
    compress = vtk.compression_level > 0

    # DataArray node
    set_attribute(xDA, "format", "appended")
    set_attribute(xDA, "offset", position(buf))

    # Size of data array (in bytes).
    nb = sizeof_data(data)

    if compress
        initpos = position(buf)

        # Write temporary data that will be replaced later with the real header.
        let header = ntuple(d -> zero(HeaderType), Val(4))
            write(buf, header...)
        end

        # Write compressed data.
        zWriter = ZlibCompressorStream(buf, level=vtk.compression_level)
        write_array(zWriter, data)
        write(zWriter, TranscodingStreams.TOKEN_END)
        flush(zWriter)

        # Go back to `initpos` and write real header.
        endpos = position(buf)
        compbytes = endpos - initpos - 4 * sizeof(HeaderType)
        let header = HeaderType.((1, nb, nb, compbytes))
            seek(buf, initpos)
            write(buf, header...)
            seek(buf, endpos)
        end
    else
        write(buf, HeaderType(nb))  # header (uncompressed version)
        nb_write = write_array(buf, data)
        @assert nb_write == nb
    end

    xDA
end

"""
    data_to_xml_inline(vtk::DatasetFile, xDA::XMLElement, data)

Add inline, base64-encoded data to VTK XML file.
"""
function data_to_xml_inline(vtk::DatasetFile, xDA::XMLElement, data)
    @assert !vtk.appended && !vtk.ascii
    compress = vtk.compression_level > 0

    # DataArray node
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
        add_text(xDA, base64encode(HeaderType.((1, nb, nb, position(buf)))...))
    else
        add_text(xDA, base64encode(HeaderType(nb)))     # header (uncompressed version)
    end
    add_text(xDA, base64encode(take!(buf)))
    add_text(xDA, "\n")

    if compress
        close(zWriter)
    end
    close(buf)

    xDA
end

"""
    data_to_xml_ascii(vtk::DatasetFile, xDA::XMLElement, data)

Add inline data to VTK XML file in ASCII format.
"""
function data_to_xml_ascii(vtk::DatasetFile, xDA::XMLElement, data)
    @assert !vtk.appended && vtk.ascii
    set_attribute(xDA, "format", "ascii")
    add_text(xDA, "\n")
    add_data_ascii(xDA, data)
    add_text(xDA, "\n")
    xDA
end

"""
    add_field_data(vtk::DatasetFile, data,
                   name::AbstractString, loc::AbstractFieldData)

Add either point or cell data to VTK file.
"""
function add_field_data(vtk::DatasetFile, data, name::AbstractString,
                        loc::AbstractFieldData)
    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, vtk.grid_type)

    xbase = if loc === VTKFieldData()
        xGrid
    else
        find_element(xGrid, "Piece")
    end

    # Find or create "nodetype" (PointData, CellData or FieldData) node.
    nodetype = node_type(loc)
    xtmp = find_element(xbase, nodetype)
    xPD = (xtmp === nothing) ? new_child(xbase, nodetype) : xtmp

    # DataArray node
    xDA = data_to_xml(vtk, xPD, data, name, loc)

    xDA
end

vtk_point_data(args...) = add_field_data(args..., VTKPointData())
vtk_cell_data(args...) = add_field_data(args..., VTKCellData())
vtk_field_data(args...) = add_field_data(args..., VTKFieldData())

"""
    setindex!(vtk::DatasetFile, data, name::AbstractString, [field_type])

Add a new dataset to VTK file.

The number of components of the dataset (e.g. for scalar or vector fields) is
determined automatically from the input data dimensions.

The optional argument `field_type` should be an instance of `VTKPointData`,
`VTKCellData` or `VTKFieldData`.
It determines whether the data should be associated to grid points, cells or
none.
If not given, this is guessed from the input data size and the grid dimensions.

# Example

Add "velocity" dataset and time scalar to VTK file.

```julia
vel = rand(3, 12, 14, 42)  # vector field
time = 42.0

vtk = vtk_grid(...)
vtk["velocity", VTKPointData()] = vel
vtk["time", VTKFieldData()] = time

# This also works, and will generally give the same result:
vtk["velocity"] = vel
vtk["time"] = time
```
"""
Base.setindex!(vtk::DatasetFile, data, name::AbstractString,
               loc::AbstractFieldData) = add_field_data(vtk, data, name, loc)

function Base.setindex!(vtk::DatasetFile, data, name::AbstractString)
    loc = guess_data_location(data, vtk) :: AbstractFieldData
    setindex!(vtk, data, name, loc)
end
