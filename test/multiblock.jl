#!/usr/bin/env julia

# This file tests generation of multiblock VTK files.
# It also tests the non-default values of the optional parameters of vtk_grid,
# i.e., compress=false and append=false.

using WriteVTK
import Compat: UTF8String, view
typealias FloatType Float32
const vtm_filename_noext = "multiblock"

# Like sub2ind, but specifically for 3D arrays.
mysub2ind(dims, i, j, k) = i + dims[1]*(j-1) + dims[1]*dims[2]*(k-1)

function first_block_data()
    const Ni, Nj, Nk = 10, 15, 20

    x = zeros(FloatType, Ni, Nj, Nk)
    y = copy(x)
    z = copy(x)

    # Just to test subarrays:
    qall = zeros(FloatType, 3Ni, 2Nj, 2Nk)
    q = view(qall, 1:Ni, 1:Nj, 1:Nk)

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

function third_block_data()
    # This is basically the same as in the unstructured example.
    const Ni, Nj, Nk = 40, 50, 20
    const dims = [Ni, Nj, Nk]

    # Create points and point data.
    pts = Array(FloatType, 3, Ni, Nj, Nk)
    pdata = Array(FloatType, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts[1, i, j, k] = r * cos(th)
        pts[2, i, j, k] = r * sin(th)
        pts[3, i, j, k] = -2 + (k - 1)/(Nk - 1)
        pdata[i, j, k] = i*i + k*sqrt(j)
    end

    # Create cells (all hexahedrons in this case) and cell data.
    const celltype = VTKCellTypes.VTK_HEXAHEDRON
    cells = MeshCell[]
    cdata = FloatType[]

    for k = 2:Nk, j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = Array(Int32, 8)
        inds[1] = mysub2ind(dims, i-1, j-1, k-1)
        inds[2] = mysub2ind(dims, i  , j-1, k-1)
        inds[3] = mysub2ind(dims, i  , j  , k-1)
        inds[4] = mysub2ind(dims, i-1, j  , k-1)
        inds[5] = mysub2ind(dims, i-1, j-1, k  )
        inds[6] = mysub2ind(dims, i  , j-1, k  )
        inds[7] = mysub2ind(dims, i  , j  , k  )
        inds[8] = mysub2ind(dims, i-1, j  , k  )

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j*k)
    end

    return pts, cells, pdata, cdata
end

function main()
    # Initialise multiblock file.
    vtm = vtk_multiblock(vtm_filename_noext)

    # Create first block.
    x, y, z, q = first_block_data()
    vtk = vtk_grid(vtm, x, y, z; compress=false, append=false)
    vtk_point_data(vtk, q, "q_values")

    # Create second block.
    x, y, z, q = second_block_data()
    vtk = vtk_grid(vtm, x, y, z; compress=false)
    vtk_point_data(vtk, q, "q_values")

    # Create third block.
    points, cells, q, c = third_block_data()
    vtk = vtk_grid(vtm, points, cells; append=false)
    vtk_point_data(vtk, q, "q_values")
    vtk_cell_data(vtk, c, "c_values")

    # Saved multiblock file and included block files.
    outfiles = vtk_save(vtm)
    println("Saved:", [" "^3 * s for s in outfiles]...)

    return outfiles::Vector{UTF8String}
end

main()
