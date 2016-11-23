# Contains common functions for all grid types.

ZlibCompressStream(buf::IO) =
    ZlibDeflateOutputStream(buf; gzip=false, level=COMPRESSION_LEVEL)


"Return the VTK string representation of a numerical data type."
function datatype_str(T::DataType)
    # Note: at least for the supported types, the VTK type names are exactly the
    # same as the Julia type names (e.g.  Float64 -> "Float64"), so that we can
    # simply use the `string` function.
    if T ∉ (Float32, Float64, Int32, Int64, UInt8)
        throw(ArgumentError("Data type not supported: $T"))
    end
    return string(T)
end

function data_to_xml{T<:Real}(
        vtk::DatasetFile, xParent::XMLElement, data::AbstractArray{T},
        varname::AbstractString, Nc::Integer=1)
    #==========================================================================
    This variant of data_to_xml should be used when writing appended data.
      * buf is the buffer where the appended data is written.
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

    Otherwise, the header is just a single UInt32 value containing the size of
    the data array in bytes.
    ==========================================================================#

    if !vtk.appended
        # Redirect to the inline version of this function.
        return data_to_xml_inline(vtk, xParent, data, varname, Nc)::XMLElement
    end

    const buf = vtk.buf    # append buffer
    const compress = vtk.compressed

    @assert name(xParent) in ("Points", "PointData", "Coordinates",
                              "Cells", "CellData")

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type", datatype_str(T))
    set_attribute(xDA, "Name", varname)
    set_attribute(xDA, "format", "appended")
    set_attribute(xDA, "offset", string(buf.position - 1))
    set_attribute(xDA, "NumberOfComponents", string(Nc))

    # Size of data array (in bytes).
    const nb = length(data) * sizeof(eltype(data))

    if compress
        const initpos = buf.position

        # Write temporary array that will be replaced later by the real header.
        header = zeros(UInt32, 4)
        write(buf, header)

        # Write compressed data.
        zWriter = ZlibCompressStream(buf)
        for val in data
            write(zWriter, val)
        end
        flush(zWriter)

        # Go back to `initpos` and write real header.
        endpos = buf.position
        compbytes = buf.position - initpos - sizeof(header)
        header[:] = [1, nb, nb, compbytes]
        buf.position = initpos
        write(buf, header)
        buf.position = endpos
    else
        write(buf, UInt32(nb))       # header (uncompressed version)
        for val in data
            write(buf, val)
        end
    end

    return xDA::XMLElement
end


function data_to_xml_inline{T<:Real}(
        vtk::DatasetFile, xParent::XMLElement, data::AbstractArray{T},
        varname::AbstractString, Nc::Integer=1)
    #==========================================================================
    This variant of data_to_xml should be used when writing data "inline" into
    the XML file (not appended at the end).

    See the other variant of this function for more info.
    ==========================================================================#

    @assert !vtk.appended
    @assert name(xParent) in ("Points", "PointData", "Coordinates",
                              "Cells", "CellData")

    const compress = vtk.compressed

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type", datatype_str(T))
    set_attribute(xDA, "Name", varname)
    set_attribute(xDA, "format", "binary")   # here, binary means base64-encoded
    set_attribute(xDA, "NumberOfComponents", "$Nc")

    # Number of bytes of data.
    const nb = length(data) * sizeof(eltype(data))

    # Write data to a buffer, which is then base64-encoded and added to the
    # XML document.
    buf = BufferedOutputStream()

    # NOTE: in the compressed case, the header and the data need to be
    # base64-encoded separately!!
    # That's why we don't use a single buffer that contains both, like in the
    # other data_to_xml function.
    if compress
        # Write compressed data.
        zWriter = ZlibCompressStream(buf)
        for val in data
            write(zWriter, val)
        end
        flush(zWriter)
    else
        for val in data
            write(buf, val)
        end
    end

    # Write buffer with data to XML document.
    add_text(xDA, "\n")
    if compress
        header = UInt32[1, nb, nb, buf.position - 1]
        add_text(xDA, base64encode(header))
    else
        add_text(xDA, base64encode(UInt32(nb)))     # header (uncompressed version)
    end
    add_text(xDA, base64encode(takebuf_string(buf)))
    add_text(xDA, "\n")

    close(buf)

    return xDA::XMLElement
end


function vtk_point_or_cell_data{T<:Real}(
        vtk::DatasetFile, data::AbstractArray{T}, name::AbstractString,
        nodetype::AbstractString, Nc::Integer)
    # Nc: number of components (Nc >= 1)

    # Find Piece node.
    xroot = root(vtk.xdoc)
    xGrid = find_element(xroot, vtk.gridType_str)
    xPiece = find_element(xGrid, "Piece")

    # Find or create "nodetype" (PointData or CellData) node.
    xtmp = find_element(xPiece, nodetype)
    xPD = (xtmp === nothing) ? new_child(xPiece, nodetype) : xtmp

    # DataArray node
    xDA = data_to_xml(vtk, xPD, data, name, Nc)

    return
end


function vtk_point_data(vtk::DatasetFile, data::AbstractArray, name::AbstractString)
    # Number of components.
    Nc = div(length(data), vtk.Npts)
    if Nc * vtk.Npts != length(data)
        throw(ArgumentError("Incorrect dimensions of input array."))
    end
    return vtk_point_or_cell_data(vtk, data, name, "PointData", Nc)
end


function vtk_cell_data(vtk::DatasetFile, data::AbstractArray, name::AbstractString)
    # Number of components.
    Nc = div(length(data), vtk.Ncls)
    if Nc * vtk.Ncls != length(data)
        throw(ArgumentError("Incorrect dimensions of input array."))
    end
    return vtk_point_or_cell_data(vtk, data, name, "CellData", Nc)
end


function vtk_save(vtk::DatasetFile)
    outfiles = [vtk.path]::Vector{UTF8String}
    if !isopen(vtk)
        return outfiles
    end

    if !vtk.appended
        save_file(vtk.xdoc, vtk.path)
        close(vtk)
        return outfiles
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

    # Write raw data (contents of buffer vtk.buf).
    # An underscore "_" is needed before writing appended data.
    write(io, "  <AppendedData encoding=\"raw\">")
    write(io, "\n_")
    write(io, takebuf_string(vtk.buf))
    write(io, "\n  </AppendedData>")
    write(io, "\n</VTKFile>")

    close(vtk.buf)
    close(vtk)
    close(io)

    return outfiles
end


function vtk_xml_write_header(vtk::DatasetFile)
    xroot = create_root(vtk.xdoc, "VTKFile")
    set_attribute(xroot, "type", vtk.gridType_str)
    set_attribute(xroot, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    if vtk.compressed
        set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
        set_attribute(xroot, "header_type", "UInt32")
    end
    return xroot::XMLElement
end


# Returns the "extent" attribute required for structured (including rectilinear)
# grids.
function extent_attribute(Ni, Nj, Nk, extent::Void=nothing)
    return @sprintf("%d %d %d %d %d %d", 0, Ni-1, 0, Nj-1, 0, Nk-1)
end

function extent_attribute{T<:Integer}(Ni, Nj, Nk, extent::Array{T})
    length(extent) == 6 || throw(ArgumentError("Extent must have length 6."))
    (extent[2] - extent[1] + 1 == Ni) &&
    (extent[4] - extent[3] + 1 == Nj) &&
    (extent[6] - extent[5] + 1 == Nk) ||
    throw(ArgumentError("Extent is not consistent with dataset dimensions."))
    return @sprintf("%d %d %d %d %d %d", extent...)
end


# Number of cells in structured grids (includes structured and rectilinear
# VTK files).
# In 3D, all cells are hexahedrons (i.e. VTK_HEXAHEDRON), and the number of
# cells is (Ni-1)*(Nj-1)*(Nk-1).
# In 2D, they are quadrilaterals (VTK_QUAD), and in 1D they are line segments
# (VTK_LINE).
function num_cells_structured(Ni, Nj, Nk)
    Ncls = one(Ni)
    for N in (Ni, Nj, Nk)
        Ncls *= max(1, N - 1)
    end
    return Ncls
end
