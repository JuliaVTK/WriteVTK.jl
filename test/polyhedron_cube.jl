# Create a cube as a single VTK_POLYHEDRON cell.
using WriteVTK

points = permutedims(Float32[
    -1 -1 -1;
     1 -1 -1;
     1  1 -1;
    -1  1 -1;
    -1 -1  1;
     1 -1  1;
     1  1  1;
    -1  1  1;
])

cells = [
    VTKPolyhedron(
        1:8,           # connectivity vector
        (1, 4, 3, 2),  # face 1
        (1, 5, 8, 4),  # face 2
        (5, 6, 7, 8),  # etc...
        (6, 2, 3, 7),
        (1, 2, 6, 5),
        (3, 4, 8, 7),
    ),
]

@time vtk_grid("polyhedron_cube", points, cells; compress = false) do vtk
    vtk["temperature"] = vec(sum(x -> abs2(x + 1), points; dims = 1))
    vtk["pressure"] = [42.0]  # one per cell
end
