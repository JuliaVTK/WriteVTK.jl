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

# Specifies the "extent" of a structured grid, e.g. (1:4, 0:3, 1:42)
const Extent{N} = Tuple{Vararg{AbstractUnitRange{<:Integer}, N}} where {N}

function maybe_check_extent(Ns::Dims{N}, ext::Extent{N}; check = true) where {N}
    check || return true
    all(pair -> pair[1] == length(pair[2]), zip(Ns, ext)) ||
        throw(DimensionMismatch("extent is not consistent with dataset dimensions."))
end

function to_extent(Ns::Dims{3}, extent::Extent{3}; kws...)
    maybe_check_extent(Ns, extent; kws...)
    extent
end

function to_extent(Ns::Dims{N}, extent::Extent{N}; kws...) where {N}
    if N > 3
        throw(ArgumentError("dimensionalities N > 3 not supported (got N = $N)"))
    elseif N < 3
        maybe_check_extent(Ns, extent; kws...)
        M = 3 - N
        (extent..., ntuple(d -> 0:0, Val(M))...)
    end
end

function to_extent(Ns::Dims, ::Nothing = nothing; kws...)
    ext = map(N -> 0:(N - 1), Ns)
    to_extent(Ns, ext; kws...)
end

# This is left for compatibility...
function to_extent(Ns::Dims{N}, ext::Array{T}; kws...) where {N, T <: Integer}
    length(ext) == 2N || throw(ArgumentError("extent must have length $(2N)."))
    rs = ntuple(i -> (ext[2i - 1]):(ext[2i]), Val(N))
    to_extent(Ns, rs; kws...)
end

# Returns the "extent" attribute required for structured (including rectilinear)
# grids.
function extent_attribute(Ns::Dims, extent = nothing; kws...)
    ext = to_extent(Ns, extent; kws...)
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
