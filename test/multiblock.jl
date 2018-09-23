#!/usr/bin/env julia

# This file tests generation of multiblock VTK files.
# It also tests the non-default values of the optional parameters of vtk_grid,
# i.e., compress=false and append=false.

using WriteVTK
using StaticArrays: SVector

const FloatType = Float32
const vtm_filename_noext = "multiblock"

function first_block_data()
    Ni, Nj, Nk = 10, 15, 20

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
    Ni, Nj, Nk = 20, 16, 12

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
    Ni, Nj, Nk = 40, 50, 20
    indices = LinearIndices((1:Ni, 1:Nj, 1:Nk))

    # Create points and point data.
    pts = Array{FloatType}(undef, 3, Ni, Nj, Nk)
    pdata = Array{FloatType}(undef, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts[1, i, j, k] = r * cos(th)
        pts[2, i, j, k] = r * sin(th)
        pts[3, i, j, k] = -2 + (k - 1)/(Nk - 1)
        pdata[i, j, k] = i*i + k*sqrt(j)
    end

    # Create cells (all hexahedrons in this case) and cell data.
    celltype = VTKCellTypes.VTK_HEXAHEDRON
    cells = MeshCell[]
    cdata = FloatType[]

    for k = 2:Nk, j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = SVector{8, Int32}(
            indices[i-1, j-1, k-1],
            indices[i  , j-1, k-1],
            indices[i  , j  , k-1],
            indices[i-1, j  , k-1],
            indices[i-1, j-1, k  ],
            indices[i  , j-1, k  ],
            indices[i  , j  , k  ],
            indices[i-1, j  , k  ])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j*k)
    end

    return pts, cells, pdata, cdata
end

function main()
    # Generate data.
    x1, y1, z1, q1 = first_block_data()
    x2, y2, z2, q2 = second_block_data()
    points3, cells3, q3, c3 = third_block_data()

    # Create multiblock file.
    @time outfiles = vtk_multiblock(vtm_filename_noext) do vtm
        # First block.
        vtk = vtk_grid(vtm, x1, y1, z1; compress=false, append=false)
        vtk_point_data(vtk, q1, "q_values")

        # Second block.
        vtk = vtk_grid(vtm, x2, y2, z2; compress=false)
        vtk_point_data(vtk, q2, "q_values")

        # Third block.
        vtk = vtk_grid(vtm, points3, cells3; append=false)
        vtk_point_data(vtk, q3, "q_values")
        vtk_cell_data(vtk, c3, "c_values")
    end
    println("Saved:  ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()
