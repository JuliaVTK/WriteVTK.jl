#!/usr/bin/env julia

using WriteVTK

using Random
using Test

const vtk_filename_noext = "polydata"

function main()
    Np = 128
    rng = MersenneTwister(42)
    points = sortslices(rand(rng, 3, Np), dims=2)

    M = Np >> 2
    @assert 4M == Np

    # Connect every `n` points to form lines.
    lines = let n = 4
        [PolyCell(PolyData.Lines(), (i + 1):(i + n)) for i = 0:(M - n)]
    end

    # Connect every `n` points to form polygons.
    polys = let n = 5
        [PolyCell(PolyData.Polys(), (i + 1):(i + n)) for i = M:(2M - n)]
    end

    # Each cell is a comination of points (vertices).
    verts = let n = 5
        [PolyCell(PolyData.Verts(), (i + 1):(i + n)) for i = 2M:(3M - n)]
    end

    # Triangle strips
    strips = let n = 12
        [PolyCell(PolyData.Strips(), (i + 1):(i + n)) for i = 3M:(4M - n)]
    end

    # Note: the order of verts, lines, polys and strips is not important.
    # One doesn't even need to pass all of them.
    all_cells = (verts, lines, polys, strips)
    num_cells = sum(length, all_cells)

    @time filenames = vtk_grid(vtk_filename_noext, points, all_cells...,
                         compress=false, append=false) do vtk
        vtk["my_point_data"] = randn(rng, 3, Np)

        # NOTE: cell data is not correctly parsed by VTK when multiple kinds of
        # cells are combined in the same dataset.
        # This seems to be a really old VTK issue:
        # - https://vtk.org/pipermail/vtkusers/2004-August/026448.html
        # - https://gitlab.kitware.com/vtk/vtk/-/issues/564
        vtk["my_cell_data"] = randn(rng, num_cells)
    end

    println("Saved:  ", filenames...)

    filenames
end

main()
