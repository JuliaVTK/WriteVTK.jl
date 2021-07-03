# Create two cubes as VTK_POLYHEDRON cells.
using WriteVTK

vpoints = Float32[
    -1, -1, -1,
     1, -1, -1,
     1,  1, -1,
    -1,  1, -1,
    -1, -1,  1,
     1, -1,  1,
     1,  1,  1,
    -1,  1,  1,
]

append!(vpoints, vpoints .+ 2)  # append points for second cube
points = reshape(vpoints, 3, :)

cells = [
    # Cube 1
    VTKPolyhedron(
        1:8,           # connectivity vector
        (1, 4, 3, 2),  # face 1
        (1, 5, 8, 4),  # face 2
        (5, 6, 7, 8),  # etc...
        (6, 2, 3, 7),
        (1, 2, 6, 5),
        (3, 4, 8, 7),
    ),
    # Cube 2
    VTKPolyhedron(
        8 .+ (1:8),         # connectivity vector
        8 .+ (1, 4, 3, 2),  # face 1
        8 .+ (1, 5, 8, 4),  # face 2
        8 .+ (5, 6, 7, 8),  # etc...
        8 .+ (6, 2, 3, 7),
        8 .+ (1, 2, 6, 5),
        8 .+ (3, 4, 8, 7),
    ),
]

@time vtk_grid("polyhedron_cube", points, cells; compress = false) do vtk
    vtk["temperature"] = vec(sum(x -> abs2(x + 1), points; dims = 1))
    vtk["pressure"] = [42.0, 84.0]  # one per cube
end
