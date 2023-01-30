using WriteVTK
using StaticArrays
using Test

points = SVector{3, Float32}[
    (0.0, 0.0, 0.0),  # id = 0 in ParaView
    (1.0, 0.0, 0.0),
    (0.0, 1.0, 0.0),
    (1.0, 1.0, 0.0),  # 3

    (0.0, 0.0, 1.0),
    (1.0, 0.0, 1.0),
    (0.0, 1.0, 1.0),
    (1.0, 1.0, 1.0),  # 7

    (0.5, 0.0, 0.0),
    (0.0, 0.5, 0.0),
    (0.5, 0.5, 0.0),
    (1.0, 0.5, 0.0),
    (0.5, 1.0, 0.0),  # 12

    (0.0, 0.0, 0.5),
    (0.5, 0.0, 0.5),
    (1.0, 0.0, 0.5),
    (0.0, 0.5, 0.5),
    (0.5, 0.5, 0.5),
    (1.0, 0.5, 0.5),
    (0.0, 1.0, 0.5),
    (0.5, 1.0, 0.5),
    (1.0, 1.0, 0.5),  # 21

    (0.5, 0.0, 1.0),
    (0.0, 0.5, 1.0),
    (0.5, 0.5, 1.0),
    (1.0, 0.5, 1.0),
    (0.5, 1.0, 1.0),  # 26
]

connectivity = 1 .+ [
    0, 1, 3, 2, 4, 5,
    7, 6, 8, 11, 12, 9,
    22, 25, 26, 23, 13, 15,
    21, 19, 16, 18, 14, 20,
    10, 24, 17,
]

cell = MeshCell(
    VTKCellTypes.VTK_LAGRANGE_HEXAHEDRON,
    connectivity,
)

@time vtk_grid(
        "lagrange_hexahedron", points, [cell];
        append = false, ascii = true, vtkversion = :latest,
    ) do vtk
    @test vtk.version == "2.2"
    vtk["point_data", VTKPointData()] = map(x⃗ -> sum(abs2, x⃗), points)
    vtk["cell_data", VTKCellData()] = 42.0
end
