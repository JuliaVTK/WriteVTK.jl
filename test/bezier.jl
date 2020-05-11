#!/usr/bin/env julia

# Reproduce the VTK_BEZIER_TETRA_quartic_solidSphereOctant.vtu file from the VTK
# test suite.

using WriteVTK

using Test

const VTK_BASENAME = "bezier_tetra_quartic_solidSphereOctant"

function main()
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

    outfiles = vtk_grid(VTK_BASENAME, points, cells) do vtk
        vtk["RationalWeights"] = rational_weights
    end

    println("Saved:  ", join(outfiles, "  "))

    outfiles
end

main()
