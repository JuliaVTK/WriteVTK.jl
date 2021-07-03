"""
    VTKPolyhedron <: AbstractMeshCell

Represents a polyhedron cell in an unstructured grid.

Using `VTKPolyhedron` should be preferred to using a `MeshCell` with a cell type
`VTKCellTypes.VTK_POLYHEDRON`, since the latter cannot hold all the necessary
information to describe a polyhedron cell.

---

    VTKPolyhedron(connectivity, faces...)

Construct polyhedron cell from connectivity vector (see [`MeshCell`](@ref) for
details) and from a list of polyhedron faces.

# Example

Create a polyhedron with 8 points and 6 faces.
This can represent a cube if the 8 points are properly positioned.

```jldoctest
julia> cell = VTKPolyhedron(
    1:8,
    (1, 4, 3, 2),
    (1, 5, 8, 4),
    (5, 6, 7, 8),
    (6, 2, 3, 7),
    (1, 2, 6, 5),
    (3, 4, 8, 7),
)
VTKPolyhedron{UnitRange{Int64}, NTuple{6, NTuple{4, Int64}}}(1:8, ((1, 4, 3, 2), (1, 5, 8, 4), (5, 6, 7, 8), (6, 2, 3, 7), (1, 2, 6, 5), (3, 4, 8, 7)))
```
"""
struct VTKPolyhedron{V <: Connectivity, Faces} <: AbstractMeshCell
    connectivity :: V
    faces :: Faces

    function VTKPolyhedron(connectivity, faces...)
        new{typeof(connectivity), typeof(faces)}(connectivity, faces)
    end
end

Base.eltype(::Type{<:VTKPolyhedron}) = VTKCellTypes.VTKCellType
cell_type(::VTKPolyhedron) = VTKCellTypes.VTK_POLYHEDRON

faces(cell::VTKPolyhedron) = cell.faces

function process_faces!(data, cell::VTKPolyhedron, offset)
    fs = faces(cell)
    num_faces = length(fs)
    num_values = 1 + sum(x -> length(x) + 1, fs)
    resize!(data, length(data) + num_values)
    @inbounds data[offset += 1] = num_faces
    @inbounds for f in fs
        data[offset += 1] = length(f)
        for idx in f
            data[offset += 1] = idx - 1  # switch to zero-based indexing
        end
    end
    num_values
end
