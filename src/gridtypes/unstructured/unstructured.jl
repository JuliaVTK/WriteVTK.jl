using VTKBase:
    AbstractMeshCell,
    Connectivity,
    MeshCell,
    grid_type,
    cell_type,
    connectivity_type

function add_cells!(vtk, xml_piece, number_attr, xml_name, cells;
                    with_types::Val=Val(true))
    Ncls = length(cells)
    write_types = with_types === Val(true)

    IntType = connectivity_type(cells) :: Type{<:Integer}

    # Create data arrays.
    offsets = Array{IntType}(undef, Ncls)

    # Write `types` array? This must be true for unstructured grids,
    # and false for polydata.
    if write_types
        types = Array{UInt8}(undef, Ncls)
    end

    Nconn = 0     # length of the connectivity array
    if Ncls >= 1  # it IS possible to have no cells
        offsets[1] = length(cells[1].connectivity)
    end

    for (n, c) in enumerate(cells)
        Npts_cell = length(c.connectivity)
        Nconn += Npts_cell
        if write_types
            types[n] = cell_type(c).vtk_id
        end
        if n >= 2
            offsets[n] = offsets[n-1] + Npts_cell
        end
    end

    # Create connectivity array.
    conn = Array{IntType}(undef, Nconn)
    n = 1
    for c in cells, i in c.connectivity
        # We transform to zero-based indexing, required by VTK.
        conn[n] = i - one(i)
        n += 1
    end

    # Add arrays to the XML file (DataArray nodes).
    set_attribute(xml_piece, number_attr, Ncls)

    xnode = new_child(xml_piece, xml_name)
    data_to_xml(vtk, xnode, conn, "connectivity")
    data_to_xml(vtk, xnode, offsets, "offsets")

    if write_types
        data_to_xml(vtk, xnode, types, "types")
    end

    maybe_write_faces(vtk, xnode, cells)

    vtk
end

# Write cell face information if needed.
# This will be the case if there are polyhedron cells (VTK_POLYHEDRON).
function maybe_write_faces(vtk, xnode, cells)
    offset = 0
    data_faces = Int[]
    data_offsets = Int[]

    for cell in cells
        ndata = process_faces!(data_faces, cell, offset)
        ndata === nothing && continue
        offset += ndata
        push!(data_offsets, offset)
    end

    if offset > 0
        data_to_xml(vtk, xnode, data_faces, "faces")
        data_to_xml(vtk, xnode, data_offsets, "faceoffsets")
    end

    nothing
end

# Regular MeshCells don't have faces.
process_faces!(data, ::MeshCell, etc...) = nothing

const CellVector = AbstractVector{<:AbstractMeshCell}

# Possible specifications for unstructured points.
const UnstructuredCoords = Union{
    AbstractMatrix,  # array with dimensions (3, Np)
    AbstractVector,  # e.g. vector of SVector{3}, with length Np
    Tuple{Vararg{AbstractVector{T},3}} where T,  # tuple of 3 vectors of length Np
}

function num_points(::UnstructuredVTKDataset, x::AbstractMatrix)
    if size(x, 1) != 3
        throw(DimensionMismatch("first dimension must have length 3"))
    end
    size(x, 2)
end

function num_points(::UnstructuredVTKDataset, x::AbstractVector)
    if _eltype_length(x) != 3
        throw(DimensionMismatch("element type of `x` must have length 3"))
    end
    length(x)
end

function num_points(::UnstructuredVTKDataset, x::Tuple)
    Ns = map(length, x)
    N = first(Ns)
    if !all(Ns .== N)
        throw(DimensionMismatch("tuples (x, y, z) must have the same length"))
    end
    N
end

function vtk_grid(dtype::VTKUnstructuredGrid, filename::AbstractString,
                  points::UnstructuredCoords, cells::CellVector;
                  kwargs...)
    Npts = num_points(dtype, points)
    Ncls = length(cells)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    xroot = vtk_xml_write_header(vtk)
    xGrid = new_child(xroot, vtk.grid_type)

    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", vtk.Npts)

    xPoints = new_child(xPiece, "Points")
    data_to_xml(vtk, xPoints, points, "Points", 3)

    add_cells!(vtk, xPiece, "NumberOfCells", "Cells", cells)

    vtk
end

# If the type of `cells` is not concrete, then try to guess the actual cell type and convert
# the vector to a concrete type.
# This usually happens when a user initialises a cell vector as MeshCell[] (which is not
# completely inferred) and then pushes cells into that vector.
function _adapt_cells(cells::AbstractVector)
    if isconcretetype(eltype(cells))
        cells
    else
        identity.(cells)  # tighten the element type of the container
    end
end

# Variant of vtk_grid with 2-D array "points".
#   size(points) = (dim, num_points), with dim ∈ {1, 2, 3}
"""
    vtk_grid(filename,
             X::AbstractMatrix,
             cells::AbstractVector{<:AbstractMeshCell};
             kwargs...)


Create an unstructured mesh  image data (`.vtu`) file.

`X` is a matrix with each column containing the Cartesian coordinates of a point
"""
function vtk_grid(filename::AbstractString, points::AbstractArray{T,2},
                  cells_in::CellVector, args...; kwargs...) where T
    dim, Npts = size(points)
    cells = _adapt_cells(cells_in)
    gtype = grid_type(eltype(cells))

    if dim == 3
        return vtk_grid(gtype, filename, points, cells, args...; kwargs...)
    end

    xyz = if dim == 2
        (
            view(points, 1, :),
            view(points, 2, :),
            Zeros{T}(Npts),
        )
    elseif dim == 1
        (
            view(points, 1, :),
            Zeros{T}(Npts),
            Zeros{T}(Npts),
        )
    else
        throw(DimensionMismatch(
            "`points` array must be of size (dim, num_points) with dim ∈ 1:3"
        ))
    end

    vtk_grid(gtype, filename, xyz, cells, args...; kwargs...)
end

# Variant of vtk_grid with 1-D arrays x, y, z.
# Size of each array: (num_points)
"""
    vtk_grid(filename,
             x::AbstractVector{T}, [y::AbstractVector{T}, [z::AbstractVector{T}]],
             cells::AbstractVector{<:AbstractMeshCell};
             kwargs...) where {T<:Number}

Create an unstructured mesh image data (`.vtu`) file.

`x`, `y` and `z` are vectors of containing the corresponding Cartesian coordinates of each point.
"""
function vtk_grid(filename::AbstractString, x::AbstractVector{T},
                  y::AbstractVector{T}, z::AbstractVector{T},
                  cells_in::CellVector, args...; kwargs...) where {T}
    if !(length(x) == length(y) == length(z))
        throw(DimensionMismatch("length of x, y and z arrays must be the same."))
    end
    points = (x, y, z)
    cells = _adapt_cells(cells_in)
    gtype = grid_type(eltype(cells))
    vtk_grid(gtype, filename, points, cells, args...; kwargs...)
end

# 2D version
function vtk_grid(filename::AbstractString, x::AbstractVector{T},
                  y::AbstractVector{T}, cells::CellVector, args...;
                  kwargs...) where {T}
    N = length(x)
    vtk_grid(filename, x, y, Zeros{T}(N), cells, args...; kwargs...)
end

# 1D version
function vtk_grid(filename::AbstractString, x::AbstractVector{T},
                  cells::CellVector, args...; kwargs...) where {T <: Number}
    N = length(x)
    vtk_grid(filename, x, Zeros{T}(N), Zeros{T}(N), cells, args...; kwargs...)
end

# This is typically the case when T = SVector{3}
"""
    vtk_grid(filename,
             xs::AbstractVector,
             cells::AbstractVector{<:AbstractMeshCell};
             kwargs...)

Create an unstructured mesh  image data (`.vtu`) file.

`xs` is a vector of coordinates, such as a vector of `SVector{3}` elements.
"""
function vtk_grid(filename::AbstractString, xs::AbstractVector,
                  cells_in::CellVector, args...; kwargs...)
    cells = _adapt_cells(cells_in)
    gtype = grid_type(eltype(cells))
    vtk_grid(gtype, filename, xs, cells, args...; kwargs...)
end

# Variant with 4-D Array (for "pseudo-unstructured" datasets, i.e., those that
# actually have a 3D structure) -- maybe this variant should be removed...
function vtk_grid(filename::AbstractString, points::AbstractArray{T,4},
                  cells_in::CellVector, args...; kwargs...) where T
    dim, Ni, Nj, Nk = size(points)
    points_r = reshape(points, dim, Ni * Nj * Nk)
    cells = _adapt_cells(cells_in)
    gtype = grid_type(eltype(cells))
    vtk_grid(gtype, filename, points_r, cells, args...; kwargs...)
end
