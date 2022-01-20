function vtk_xml_write_header(vtk::DatasetFile)
    xroot = create_root(vtk.xdoc, "VTKFile")
    set_attribute(xroot, "type", vtk.grid_type)
    set_attribute(xroot, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    set_attribute(xroot, "header_type", string(HeaderType))
    if vtk.compression_level > 0
        set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
    end
    xroot::XMLElement
end

# Specifies the "extent" of a structured grid, e.g. (1:4, 1:3, 1:42)
const Extent{N} = Tuple{Vararg{AbstractUnitRange{<:Integer}, N}} where {N}

# Switch to zero-based extent used by VTK.
to_vtk_extent(r::AbstractUnitRange) = r .- 1

function to_vtk_extent(extent::Union{Tuple, AbstractArray})
    ext = to_extent3(extent)
    map(to_vtk_extent, ext)
end

# Convert different extent specifications to Extent{3}.
to_extent3(extent::Extent{3}) = extent

function to_extent3(extent::Extent{N}) where {N}
    if N > 3
        throw(ArgumentError("dimensionalities N > 3 not supported (got N = $N)"))
    elseif N < 3
        M = 3 - N
        (extent..., ntuple(d -> Base.OneTo(1), Val(M))...) :: Extent{3}
    end
end

to_extent3(Ns::Dims) = to_extent3(map(Base.OneTo, Ns))

# Returns the "extent" attribute required for structured (including rectilinear)
# grids.
function extent_attribute(extent_in)
    ext = to_vtk_extent(extent_in)
    iter = Iterators.map(e -> string(first(e), " ", last(e)), ext)
    join(iter, " ")
end

# Number of cells in structured grids.
# In 3D, all cells are hexahedrons (i.e. VTK_HEXAHEDRON), and the number of
# cells is (Ni-1)*(Nj-1)*(Nk-1). In 2D, they are quadrilaterals (VTK_QUAD), and in
# 1D they are line segments (VTK_LINE).
function num_cells_structured(Ns::Dims)
    prod(N -> max(1, N - 1), Ns)
end

# Accept passing coordinates as a tuple.
vtk_grid(filename, coords::NTuple; kwargs...) =
    vtk_grid(filename, coords...; kwargs...)
