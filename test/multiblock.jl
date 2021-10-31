#!/usr/bin/env julia

# This file tests generation of multiblock VTK files.
# It also tests the non-default values of the optional parameters of vtk_grid,
# i.e., compress=false and append=false.

using WriteVTK
using StaticArrays: SVector
import OffsetArrays: OffsetArray

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

function fourth_block_data()
    # Create unstructured example with boundaries.
    imax, jmax, kmax = 25, 30, 20
    indices = LinearIndices((1:imax, 1:jmax, 1:kmax))

    # Create points and point data.
    pts_vol = Array{FloatType}(undef, 3, imax, jmax, kmax)
    pdata_vol = Array{FloatType}(undef, imax, jmax, kmax)

    x = pts_vol[1, :, :, :] .= reshape(range(0.0, stop=1.0, length=imax), imax, 1, 1)
    y = pts_vol[2, :, :, :] .= reshape(range(-1.0, stop=0.0, length=jmax), 1, jmax, 1)
    z = pts_vol[3, :, :, :] .= reshape(range(3.0, stop=4.0, length=kmax), 1, 1, kmax)

    @. pdata_vol = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    # Create cells (all tetrahedra in this case) and cell data.
    celltype = VTKCellTypes.VTK_TETRA
    cells_vol = MeshCell[]
    cdata_vol = FloatType[]

    for k = 1:kmax-1, j = 1:jmax-1, i = 1:imax-1
        # 1, 3, 4, 5
        inds = SVector{4, Int32}(
            indices[i, j, k],
            indices[i+1, j, k+1],
            indices[i, j, k+1],
            indices[i, j+1, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

        # 8, 5, 4, 3
        inds = SVector{4, Int32}(
            indices[i, j+1, k+1],
            indices[i, j+1, k],
            indices[i, j, k+1],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

        # 8, 7, 5, 3
        inds = SVector{4, Int32}(
            indices[i, j+1, k+1],
            indices[i+1, j+1, k+1],
            indices[i, j+1, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

        # 7, 6, 5, 3
        inds = SVector{4, Int32}(
            indices[i+1, j+1, k+1],
            indices[i+1, j+1, k],
            indices[i, j+1, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

        # 6, 2, 5, 3
        inds = SVector{4, Int32}(
            indices[i+1, j+1, k],
            indices[i+1, j, k],
            indices[i, j+1, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

        # 5, 2, 1, 3
        inds = SVector{4, Int32}(
            indices[i, j+1, k],
            indices[i+1, j, k],
            indices[i, j, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_vol, c)
        push!(cdata_vol, i*j*k)

    end

    # Create the block for the imin patch.

    indices = LinearIndices((1:1, 1:jmax, 1:kmax))

    # Create points and point data for the imin patch.
    pts_imin = Array{FloatType}(undef, 3, 1, jmax, kmax)
    pdata_imin = Array{FloatType}(undef, 1, jmax, kmax)

    x = pts_imin[1, :, :, :] .= pts_vol[1, 1:1, :, :]
    y = pts_imin[2, :, :, :] .= pts_vol[2, 1:1, :, :]
    z = pts_imin[3, :, :, :] .= pts_vol[3, 1:1, :, :]

    @. pdata_imin = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_imin = MeshCell[]
    cdata_imin = FloatType[]

    for k = 1:kmax-1, j = 1:jmax-1, i = 1:1
        # 1, 3, 4, 5
        inds = SVector{3, Int32}(
            indices[i, j, k],
            indices[i, j, k+1],
            indices[i, j+1, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_imin, c)
        push!(cdata_imin, i*j*k)

        # 8, 5, 4, 3
        inds = SVector{3, Int32}(
            indices[i, j+1, k+1],
            indices[i, j+1, k],
            indices[i, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_imin, c)
        push!(cdata_imin, i*j*k)

    end

    # Create the block for the imax patch.

    indices = LinearIndices((imax:imax, 1:jmax, 1:kmax))
    # Use an OffsetArray to make the indexing easier.
    indices = OffsetArray(indices, (imax:imax, 1:jmax, 1:kmax))

    # Create points and point data for the imin patch.
    pts_imax = Array{FloatType}(undef, 3, 1, jmax, kmax)
    pdata_imax = Array{FloatType}(undef, 1, jmax, kmax)

    x = pts_imax[1, :, :, :] .= pts_vol[1, imax:imax, :, :]
    y = pts_imax[2, :, :, :] .= pts_vol[2, imax:imax, :, :]
    z = pts_imax[3, :, :, :] .= pts_vol[3, imax:imax, :, :]

    @. pdata_imax = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_imax = MeshCell[]
    cdata_imax = FloatType[]

    for k = 1:kmax-1, j = 1:jmax-1, i = imax-1:imax-1
        # 7, 6, 5, 3
        inds = SVector{3, Int32}(
            indices[i+1, j+1, k+1],
            indices[i+1, j+1, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_imax, c)
        push!(cdata_imax, i*j*k)

        # 6, 2, 5, 3
        inds = SVector{3, Int32}(
            indices[i+1, j+1, k],
            indices[i+1, j, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_imax, c)
        push!(cdata_imax, i*j*k)

    end

    # Create the block for the jmin patch.

    indices = LinearIndices((1:imax, 1:1, 1:kmax))

    # Create points and point data for the jmin patch.
    pts_jmin = Array{FloatType}(undef, 3, imax, 1, kmax)
    pdata_jmin = Array{FloatType}(undef, imax, 1, kmax)

    x = pts_jmin[1, :, :, :] .= pts_vol[1, 1:imax, 1:1, :]
    y = pts_jmin[2, :, :, :] .= pts_vol[2, 1:imax, 1:1, :]
    z = pts_jmin[3, :, :, :] .= pts_vol[3, 1:imax, 1:1, :]

    @. pdata_jmin = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_jmin = MeshCell[]
    cdata_jmin = FloatType[]

    for k = 1:kmax-1, j = 1:1, i = 1:imax-1
        # 1, 3, 4, 5
        inds = SVector{3, Int32}(
            indices[i, j, k],
            indices[i+1, j, k+1],
            indices[i, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_jmin, c)
        push!(cdata_jmin, i*j*k)

        # 5, 2, 1, 3
        inds = SVector{3, Int32}(
            indices[i+1, j, k],
            indices[i, j, k],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_jmin, c)
        push!(cdata_jmin, i*j*k)

    end

    # Create the block for the jmax patch.

    indices = LinearIndices((1:imax, jmax:jmax, 1:kmax))
    # Use an OffsetArray to make the indexing easier.
    indices = OffsetArray(indices, (1:imax, jmax:jmax, 1:kmax))

    # Create points and point data for the imin patch.
    pts_jmax = Array{FloatType}(undef, 3, imax, 1, kmax)
    pdata_jmax = Array{FloatType}(undef, imax, 1, kmax)

    x = pts_jmax[1, :, :, :] .= pts_vol[1, :, jmax:jmax, :]
    y = pts_jmax[2, :, :, :] .= pts_vol[2, :, jmax:jmax, :]
    z = pts_jmax[3, :, :, :] .= pts_vol[3, :, jmax:jmax, :]

    @. pdata_jmax = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_jmax = MeshCell[]
    cdata_jmax = FloatType[]

    for k = 1:kmax-1, j = jmax-1:jmax-1, i = 1:imax-1
        # 8, 7, 5, 3
        inds = SVector{3, Int32}(
            indices[i, j+1, k+1],
            indices[i+1, j+1, k+1],
            indices[i, j+1, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_jmax, c)
        push!(cdata_jmax, i*j*k)

        # 7, 6, 5, 3
        inds = SVector{3, Int32}(
            indices[i+1, j+1, k+1],
            indices[i+1, j+1, k],
            indices[i, j+1, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_jmax, c)
        push!(cdata_jmax, i*j*k)

    end

    # Create the block for the kmin patch.

    indices = LinearIndices((1:imax, 1:jmax, 1:1))

    # Create points and point data for the kmin patch.
    pts_kmin = Array{FloatType}(undef, 3, imax, jmax, 1)
    pdata_kmin = Array{FloatType}(undef, imax, jmax, 1)

    x = pts_kmin[1, :, :, :] .= pts_vol[1, :, :, 1:1]
    y = pts_kmin[2, :, :, :] .= pts_vol[2, :, :, 1:1]
    z = pts_kmin[3, :, :, :] .= pts_vol[3, :, :, 1:1]

    @. pdata_kmin = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_kmin = MeshCell[]
    cdata_kmin = FloatType[]

    for k = 1:1, j = 1:jmax-1, i = 1:imax-1
        # 6, 2, 5, 3
        inds = SVector{3, Int32}(
            indices[i+1, j+1, k],
            indices[i+1, j, k],
            indices[i, j+1, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_kmin, c)
        push!(cdata_kmin, i*j*k)

        # 5, 2, 1, 3
        inds = SVector{3, Int32}(
            indices[i, j+1, k],
            indices[i+1, j, k],
            indices[i, j, k])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_kmin, c)
        push!(cdata_kmin, i*j*k)

    end

    # Create the block for the kmax patch.

    indices = LinearIndices((1:imax, 1:jmax, kmax:kmax))
    # Use an OffsetArray to make the indexing easier.
    indices = OffsetArray(indices, (1:imax, 1:jmax, kmax:kmax))

    # Create points and point data for the imin patch.
    pts_kmax = Array{FloatType}(undef, 3, imax, jmax, 1)
    pdata_kmax = Array{FloatType}(undef, imax, jmax, 1)

    x = pts_kmax[1, :, :, :] .= pts_vol[1, :, :, kmax:kmax]
    y = pts_kmax[2, :, :, :] .= pts_vol[2, :, :, kmax:kmax]
    z = pts_kmax[3, :, :, :] .= pts_vol[3, :, :, kmax:kmax]

    @. pdata_kmax = sin(2*pi*x)*sin(4*pi*y)*sin(6*pi*z)

    celltype = VTKCellTypes.VTK_TRIANGLE
    cells_kmax = MeshCell[]
    cdata_kmax = FloatType[]

    for k = kmax-1:kmax-1, j = 1:jmax-1, i = 1:imax-1
        # 8, 5, 4, 3
        inds = SVector{3, Int32}(
            indices[i, j+1, k+1],
            indices[i, j, k+1],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_kmax, c)
        push!(cdata_kmax, i*j*k)

        # 8, 7, 5, 3
        inds = SVector{3, Int32}(
            indices[i, j+1, k+1],
            indices[i+1, j+1, k+1],
            indices[i+1, j, k+1])

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells_kmax, c)
        push!(cdata_kmax, i*j*k)

    end

    return ((pts_vol, cells_vol, pdata_vol, cdata_vol),
            (pts_imin, cells_imin, pdata_imin, cdata_imin),
            (pts_imax, cells_imax, pdata_imax, cdata_imax),
            (pts_jmin, cells_jmin, pdata_jmin, cdata_jmin),
            (pts_jmax, cells_jmax, pdata_jmax, cdata_jmax),
            (pts_kmin, cells_kmin, pdata_kmin, cdata_kmin),
            (pts_kmax, cells_kmax, pdata_kmax, cdata_kmax))

end

function main()
    # Generate data.
    x1, y1, z1, q1 = first_block_data()
    x2, y2, z2, q2 = second_block_data()
    points3, cells3, q3, c3 = third_block_data()
    ((points4, cells4, q4, c4),
     (points41, cells41, q41, c41),
     (points42, cells42, q42, c42),
     (points43, cells43, q43, c43),
     (points44, cells44, q44, c44),
     (points45, cells45, q45, c45),
     (points46, cells46, q46, c46)) = fourth_block_data()

    # Create multiblock file.
    @time outfiles = vtk_multiblock(vtm_filename_noext) do vtm
        # First block.
        vtk = vtk_grid(vtm, x1, y1, z1; compress=false, append=false)
        vtk["q_values"] = q1

        # Second block.
        vtk = vtk_grid(vtm, x2, y2, z2; compress=false)
        vtk["q_values"] = q2

        # Third block.
        vtk = vtk_grid(vtm, points3, cells3; append=false)
        vtk["q_values"] = q3
        vtk["c_values"] = c3

        # Fourth block is a collection of multiblock files itself.
        block = multiblock_add_block(vtm, "multiblock_4")
        vtk_grid(block, "multiblock_4_volume", points4, cells4) do vtk
            vtk["q_values"] = q4
            vtk["c_values"] = c4
        end
        vtk_grid(block, "multiblock_4_imin", points41, cells41) do vtk
            vtk["q_values"] = q41
            vtk["c_values"] = c41
        end
        vtk_grid(block, "multiblock_4_imax", points42, cells42) do vtk
            vtk["q_values"] = q42
            vtk["c_values"] = c42
        end
        vtk_grid(block, "multiblock_4_jmin", points43, cells43) do vtk
            vtk["q_values"] = q43
            vtk["c_values"] = c43
        end
        vtk_grid(block, "multiblock_4_jmax", points44, cells44) do vtk
            vtk["q_values"] = q44
            vtk["c_values"] = c44
        end
        vtk_grid(block, "multiblock_4_kmin", points45, cells45) do vtk
            vtk["q_values"] = q45
            vtk["c_values"] = c45
        end
        vtk_grid(block, "multiblock_4_kmax", points46, cells46) do vtk
            vtk["q_values"] = q46
            vtk["c_values"] = c46
        end

        points = copy(points4)
        points[3, :, :, :] .+= 1
        vtk_grid(identity, block, points, cells4)  # unnamed VTK file

        subblock = multiblock_add_block(vtm)  # unnamed nested block
        points[1, :, :, :] .+= 1.2
        vtk_grid(identity, subblock, points, cells4)  # unnamed nested block + unnamed VTK file

        points[2, :, :, :] .+= 2.1
        vtk_grid(identity, subblock, "very_nested", points, cells4)  # unnamed nested block + named VTK file

        subsubblock_named = multiblock_add_block(subblock, "nested-nested")
        subsubblock_unnamed = multiblock_add_block(subblock)

        vtk_grid(identity, subsubblock_named, points .- 2, cells4)
    end

    println("Saved:  ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()
