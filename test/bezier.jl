#!/usr/bin/env julia


using WriteVTK

using Test

const VTK_BASENAME_SPHERE = "bezier_tetra_quartic_solidSphereOctant"
const VTK_BASENAME_ANNULUS = "bezier_anisotropic_degree_quarterAnnulus"

# Reproduce the VTK_BEZIER_TETRA_quartic_solidSphereOctant.vtu file from the VTK
# test suite
function bezier_tetra_quartic_solid_sphere_octant()
    cell_type = VTKCellTypes.VTK_BEZIER_TETRAHEDRON

    # Copied from VTK generated file.
    points_in = [
        1, 0, 0, 0, 1, 0,
        0, 0, 1, 0, 0, 0,
        1, 0.4226497411727905, 0, 0.7886751294136047, 0.7886751294136047, 0,
        0.4226497411727905, 1, 0, 0, 1, 0.4226497411727905,
        0, 0.7886751294136047, 0.7886751294136047, 0, 0.4226497411727905, 1,
        0.4226497411727905, 0, 1, 0.7886751294136047, 0, 0.7886751294136047,
        1, 0, 0.4226497411727905, 0.75, 0, 0,
        0.5, 0, 0, 0.25, 0, 0,
        0, 0.75, 0, 0, 0.5, 0,
        0, 0.25, 0, 0, 0, 0.75,
        0, 0, 0.5, 0, 0, 0.25,
        0.5, 0.25, 0, 0.25, 0.5, 0,
        0.25, 0.25, 0, 0, 0.25, 0.5,
        0, 0.25, 0.25, 0, 0.5, 0.25,
        0.5, 0, 0.25, 0.25, 0, 0.25,
        0.25, 0, 0.5, 1, 0.5893534421920776, 0.5893534421920776,
        0.5893534421920776, 0.5893534421920776, 1, 0.5893534421920776, 1, 0.5893534421920776,
        0.30000001192092896, 0.30000001192092896, 0.30000001192092896,
    ]
    points = reshape(points_in, 3, :)

    connectivity = 1:size(points, 2)

    rational_weights = [
        1, 1, 1, 1, 0.8365163037378083, 0.7886751345948131,
        0.8365163037378083, 0.8365163037378083, 0.7886751345948131, 0.8365163037378083, 0.8365163037378083, 0.7886751345948131,
        0.8365163037378083, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 0.6594659464934113, 0.6594659464934113, 0.6594659464934113, 1,
    ]

    cells = [MeshCell(cell_type, connectivity)]

    output = vtk_grid(VTK_BASENAME_SPHERE, points, cells; vtkversion = v"1.0") do vtk
        @test vtk.version == "1.0"
        vtk["RationalWeights"] = rational_weights
        vtk[VTKPointData()] = "RationalWeights" => "RationalWeights"
    end
end

# Test Bezier quadrilateral with anisotropic degrees
function bezier_anisotropic_degree_quarter_annulus()
    cell_type = VTKCellTypes.VTK_BEZIER_QUADRILATERAL
    points = [1.0 0.0 0.0 2.0 1.0 2.0; 0.0 1.0 2.0 0.0 1.0 2.0]
    connectivity = 1:size(points, 2)
    rational_weights = [1.0, 1.0, 1.0, 1.0, sqrt(0.5), sqrt(0.5)]
    cells = [MeshCell(cell_type, connectivity)]

    output = vtk_grid(VTK_BASENAME_ANNULUS, points, cells; vtkversion = v"1.0") do vtk
        vtk["HigherOrderDegrees", VTKCellData()] = [2.0 1.0 1.0]
        vtk["RationalWeights", VTKPointData()] = rational_weights
        vtk[VTKPointData()] = "RationalWeights" => "RationalWeights"
        vtk[VTKCellData()] = "HigherOrderDegrees" => "HigherOrderDegrees"
    end
end

function main()
    files = String[]

    let
        @time output = bezier_tetra_quartic_solid_sphere_octant()
        append!(files, output)
    end

    let
        @time output = bezier_anisotropic_degree_quarter_annulus()
        append!(files, output)
    end

    println("Saved:  ", join(files, "  "))
    files
end

main()
