#!/usr/bin/env julia

using WriteVTK
typealias FloatType Float32
const vtm_filename_noext = "multiblock"

function first_block_data()
    const Ni, Nj, Nk = 10, 15, 20

    x = zeros(FloatType, Ni, Nj, Nk)
    y = copy(x)
    z = copy(x)
    q = copy(x)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        r::FloatType = 1 + (i - 1)/(Ni - 1)
        th::FloatType = 3*pi/4 * (j-1) / (Nj-1)
        x[i, j, k] = r * cos(th)
        y[i, j, k] = r * sin(th)
        z[i, j, k] = (k-1) / (Nk-1)
        q[i, j, k] = k * exp(j) * sqrt(i)
    end

    return x, y, z, q
end

function second_block_data()
    const Ni, Nj, Nk = 20, 16, 12

    x = zeros(FloatType, Ni)
    y = zeros(FloatType, Nj)
    z = zeros(FloatType, Nk)

    [x[i] =  1 +   (i-1) / (Ni-1) for i = 1:Ni]
    [y[j] = -2 + 2*(j-1) / (Nj-1) for j = 1:Nj]
    [z[k] =        (k-1) / (Nk-1) for k = 1:Nk]

    q = zeros(FloatType, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        q[i, j, k] = k * exp(j) * sqrt(i)
    end

    return x, y, z, q
end

function main()
    # Initialise multiblock file.
    vtm = vtk_multiblock(vtm_filename_noext)

    # Create first block.
    x, y, z, q = first_block_data()
    vtk = vtk_grid(vtm, x, y, z)
    vtk_point_data(vtk, q, "q_values")

    # Create second block.
    x, y, z, q = second_block_data()
    vtk = vtk_grid(vtm, x, y, z)
    vtk_point_data(vtk, q, "q_values")

    # Saved multiblock file and included block files.
    filename_vtm = vtk_save(vtm)
    println("Saved ", filename_vtm)

    # Just for running tests (ignore!):
    paths = [filename_vtm]
    [push!(paths, vtk.path) for vtk in vtm.blocks]

    return paths::Vector{UTF8String}
end

main()
