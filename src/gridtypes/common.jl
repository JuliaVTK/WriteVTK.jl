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


# Returns the "extent" attribute required for structured (including rectilinear)
# grids.
extent_attribute(Ni, Nj, Nk, ::Nothing=nothing) =
    "0 $(Ni - 1) 0 $(Nj - 1) 0 $(Nk - 1)"

function extent_attribute(Ni, Nj, Nk, extent::Array{T}) where T <: Integer
    length(extent) == 6 || throw(ArgumentError("extent must have length 6."))
    (extent[2] - extent[1] + 1 == Ni) &&
    (extent[4] - extent[3] + 1 == Nj) &&
    (extent[6] - extent[5] + 1 == Nk) ||
    throw(ArgumentError("extent is not consistent with dataset dimensions."))
    join(extent, " ")
end

# Number of cells in structured grids.
# In 3D, all cells are hexahedrons (i.e. VTK_HEXAHEDRON), and the number of
# cells is (Ni-1)*(Nj-1)*(Nk-1). In 2D, they are quadrilaterals (VTK_QUAD), and in
# 1D they are line segments (VTK_LINE).
function num_cells_structured(Ni, Nj, Nk)
    Ncls = one(Ni)
    for N in (Ni, Nj, Nk)
        Ncls *= max(1, N - 1)
    end
    Ncls
end

# Accept passing coordinates as a tuple.
vtk_grid(filename, coords::NTuple; kwargs...) =
    vtk_grid(filename, coords...; kwargs...)
