#!/usr/bin/env julia

using WriteVTK

using Random
using Test

const vtk_filename_noext = "polydata"

# Write file with D-dimensional grid.
function write_vtp(Np, D)
    rng = MersenneTwister(42)

    # Workaround changes in rand output in Julia 1.5. See array.jl.
    points = sortslices([rand(rng) for i = 1:D, j = 1:Np], dims=2)

    M = Np >> 2
    @assert 4M == Np

    # Connect every `n` points to form lines.
    lines = let n = 4
        # Try using tuples for connectivity info.
        [MeshCell(PolyData.Lines(), ntuple(d -> i + d, Val(4))) for i = 0:(M - n)]
    end

    # Connect every `n` points to form polygons.
    polys = let n = 5
        [MeshCell(PolyData.Polys(), (i + 1):(i + n)) for i = M:(2M - n)]
    end

    # Each cell is a comination of points (vertices).
    verts = let n = 5
        [MeshCell(PolyData.Verts(), (i + 1):(i + n)) for i = 2M:(3M - n)]
    end

    # Triangle strips
    strips = let n = 12
        [MeshCell(PolyData.Strips(), (i + 1):(i + n)) for i = 3M:(4M - n)]
    end

    # Note: the order of verts, lines, polys and strips is not important.
    # One doesn't even need to pass all of them.
    all_cells = (verts, lines, polys, strips)
    num_cells = sum(length, all_cells)

    fname = vtk_filename_noext * "_$(D)D"
    print("PolyData $(D)D...")
    @time filenames = vtk_grid(fname, points, all_cells...,
                               compress=false, append=false, ascii=true) do vtk
        vtk["my_point_data"] = [randn(rng) for i = 1:3, j = 1:Np]
        vtk["vector_as_tuple"] = ntuple(_ -> [randn(rng) for j = 1:Np], D)
        # NOTE: cell data is not correctly parsed by VTK when multiple kinds of
        # cells are combined in the same dataset.
        # This seems to be a really old VTK issue:
        # - https://vtk.org/pipermail/vtkusers/2004-August/026448.html
        # - https://gitlab.kitware.com/vtk/vtk/-/issues/564
        vtk["my_cell_data"] = [randn(rng) for j = 1:num_cells]
    end
end

function empty_cells()
    points = [0 0 0; 1. 1. 1.]
    vel = [0 .5 .5; 1 1 0]
    verts = MeshCell{PolyData.Verts}[]
    vtk_grid("parts.vtp", points, verts) do vtk
        vtk["vel"] = vel
    end
end

function main()
    empty_cells()

    Np = 128
    filenames = vcat(write_vtp.(Np, 2:3)...)
    println("Saved:  ", join(filenames, "  "))
    filenames
end

main()
