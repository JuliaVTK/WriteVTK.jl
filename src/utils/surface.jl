export vtk_surface

using Base: @propagate_inbounds

# Internal type for representing a vector as a matrix where quantities vary only
# along one dimension (`Dim`).
struct RepeatedVector{
        Dim, T, V <: AbstractVector{T},
        Axes,
    } <: AbstractMatrix{T}
    data :: V
    axes :: Axes
    function RepeatedVector{Dim}(data::AbstractVector, axes_other) where {Dim}
        @assert Dim ∈ (1, 2)
        axs = ntuple(d -> d == Dim ? axes(data, 1) : axes_other, Val(2))
        new{Dim, eltype(data), typeof(data), typeof(axs)}(data, axs)
    end
end

Base.axes(u::RepeatedVector) = u.axes
Base.size(u::RepeatedVector) = map(length, axes(u))

@propagate_inbounds Base.getindex(u::RepeatedVector{1}, i, _) = u.data[i]
@propagate_inbounds Base.getindex(u::RepeatedVector{2}, _, j) = u.data[j]

_meshgrid(xs::AbstractVector, ys::AbstractVector) = (
    RepeatedVector{1}(xs, axes(ys, 1)),
    RepeatedVector{2}(ys, axes(xs, 1)),
)

function _generate_quad_cells!(cells::Matrix)
    Nx = size(cells, 1) + 1
    for I ∈ CartesianIndices(cells)
        # Create rectangular cell with corners at:
        #
        #   (i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)
        #
        # Note that we need to convert those indices to linear indices.
        i, j = Tuple(I)
        a = Nx * (j - 1) + i  # (i,     j)
        b = a + 1             # (i + 1, j)
        c = b + Nx            # (i + 1, j + 1)
        d = c - 1             # (i,     j + 1)
        connectivity = (a, b, c, d)
        cells[I] = MeshCell(VTKCellTypes.VTK_QUAD, connectivity)
    end
    cells
end

"""
    vtk_surface([f::Function], filename, xs, ys, zs; kwargs...)

Create unstructured grid file (".vtu") representing a surface plot of a 2D
function on coordinates (`xs`, `ys`) with values `zs`.

The coordinates `xs` and `ys` can be given as:

- 1D arrays of respective dimensions `Nx` and `Ny` (for regular grids);
- 2D arrays of dimensions `(Nx, Ny)` (for irregular grids).

The values `zs` should be given in a 2D array of dimensions `(Nx, Ny)`.

# Including additional data

Optionally, one can write additional data to the generated file via the function
`f`, which works in the same way as for [`vtk_grid`](@ref).

As an example, it is common to colour surface plots by the height `z`.
To do this, one should write the `zs` matrix as point data:

```julia
julia> xs = 0:0.5:10; ys = 0:1.0:20;

julia> zs = @. cos(xs) + sin(ys');

julia> vtk_surface("surf", xs, ys, zs) do vtk
           vtk["z_values"] = zs
       end
```

Note that the included data must have dimensions `(Nx, Ny)` (for point data) or
`(Nx - 1, Ny - 1)` (for cell data).
"""
function vtk_surface(
        f::F,
        filename::AbstractString,
        xs::AbstractMatrix, ys::AbstractMatrix,
        zs::AbstractMatrix;
        kwargs...,
    ) where {F}
    if !(size(xs) == size(ys) == size(zs))
        throw(DimensionMismatch("input arrays have incompatible dimensions"))
    end
    Nx, Ny = size(zs)
    QuadCell = typeof(MeshCell(VTKCellTypes.VTK_QUAD, (1, 2, 3, 4)))
    cells = Array{QuadCell}(undef, Nx - 1, Ny - 1)
    _generate_quad_cells!(cells)
    vtk_grid(f, filename, vec(xs), vec(ys), vec(zs), vec(cells); kwargs...)
end

# Case of a regular grid: coordinates passed as vectors.
function vtk_surface(
        f::F,
        filename::AbstractString,
        xs::AbstractVector, ys::AbstractVector,
        zs::AbstractMatrix;
        kwargs...,
    ) where {F}
    Xs, Ys = _meshgrid(xs, ys)
    vtk_surface(f, filename, Xs, Ys, zs; kwargs...)
end

vtk_surface(filename::AbstractString, args...; kws...) =
    vtk_surface(identity, filename, args...; kws...)
