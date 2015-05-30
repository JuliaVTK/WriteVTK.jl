# Contains common functions for all grid types.

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

    Otherwise, the header is just a single UInt32 value containing the size of
    the data array in bytes.
    ==========================================================================#

    if !vtk.appended
        # Redirect to the inline version of this function.
        return data_to_xml_inline(vtk, xParent, data, Nc, varname)::XMLElement
    end

    const bapp = vtk.buf    # append buffer
    const compress = vtk.compressed

    @assert name(xParent) in ("Points", "PointData", "Coordinates",
                              "Cells", "CellData")

    sType = T === Float32 ? "Float32" :
            T === Float64 ? "Float64" :
            T === Int32   ? "Int32"   :
            T === UInt8   ? "UInt8"   :
            error("Real subtype not supported: $T")

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type",   sType)
    set_attribute(xDA, "Name",   varname)
    set_attribute(xDA, "format", "appended")
    set_attribute(xDA, "offset", "$(bapp.size)")
    set_attribute(xDA, "NumberOfComponents", "$Nc")

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

    return xDA::XMLElement
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

    sType = T === Float32 ? "Float32" :
            T === Float64 ? "Float64" :
            T === Int32   ? "Int32"   :
            T === UInt8   ? "UInt8"   :
            error("Real subtype not supported: $T")

    # DataArray node
    xDA = new_child(xParent, "DataArray")
    set_attribute(xDA, "type",   sType)
    set_attribute(xDA, "Name",   varname)
    set_attribute(xDA, "format", "binary")   # here, binary means base64-encoded
    set_attribute(xDA, "NumberOfComponents", "$Nc")

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

    return xDA::XMLElement
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


function vtk_cell_data(vtk::UnstructuredFile, data::Array, name::AbstractString)
    # Number of components.
    Nc = div(length(data), vtk.Ncls)
    @assert Nc*vtk.Ncls == length(data)
    return vtk_point_or_cell_data(vtk, data, name, "CellData", Nc)
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


function vtk_xml_write_header(vtk::DatasetFile)
    xroot = create_root(vtk.xdoc, "VTKFile")
    set_attribute(xroot, "type", vtk.gridType_str)
    set_attribute(xroot, "version", "1.0")
    set_attribute(xroot, "byte_order", "LittleEndian")
    if vtk.compressed
        set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
        set_attribute(xroot, "header_type", "UInt32")
    end
    return xroot::XMLElement
end
