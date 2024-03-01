#!/usr/bin/env julia

using WriteVTK

using StableRNGs: StableRNG
using Test

const vtk_filename_noext = "polydata"

# Version of randn that is stable across different julia versions
# Ref: https://github.com/DEShawResearch/random123/blob/9545ff6413f258be2f04c1d319d99aaef7521150/include/Random123/boxmuller.hpp
function my_randn(rng::StableRNG, dims::Integer...)
    # Box–Muller transform
    u01 = rand(rng, UInt64, dims...) .* (2.0^-64) .+ (2.0^-65)
    uneg11 = rand(rng, Int64, dims...) .* (2.0^-63) .+ (2.0^-64)
    sqrt.(-2 .* log.(u01)) .* cospi.(uneg11)
end

# Write file with D-dimensional grid.
function write_vtp(Np, D)
    rng = StableRNG(42)

    points = sortslices(rand(rng, D, Np), dims=2)

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
        vtk["my_point_data"] = my_randn(rng, 3, Np)
        vtk["vector_as_tuple"] = ntuple(_ -> my_randn(rng, Np), D)
        # NOTE: cell data is not correctly parsed by VTK when multiple kinds of
        # cells are combined in the same dataset.
        # This seems to be a really old VTK issue:
        # - https://vtk.org/pipermail/vtkusers/2004-August/026448.html
        # - https://gitlab.kitware.com/vtk/vtk/-/issues/564
        vtk["my_cell_data"] = my_randn(rng, num_cells)
    end
end

function empty_cells()
    points = [0 0 0; 1. 1. 1.]
    vel = [0 .5 .5; 1 1 0]
    verts = MeshCell{PolyData.Verts, Vector{Int}}[]
    @test isconcretetype(eltype(verts))
    @time filenames = vtk_grid(
            "empty_cells.vtp", points, verts,
            compress=false, append=false, ascii=true,
            vtkversion = :default,
        ) do vtk
        @test vtk.version == "1.0"
        vtk["vel"] = vel
    end
end

function main()
    filenames = empty_cells()

    Np = 128
    append!(filenames, write_vtp.(Np, 2:3)...)
    println("Saved:  ", join(filenames, "  "))

    filenames
end

main()
