#!/usr/bin/env julia

# Create unstructured grid VTK file.

using WriteVTK
import Compat.UTF8String
typealias FloatType Float32
const vtk_filename_noext = "unstructured"

# 3D mesh
function mesh_data(::Val{3})
    # This is basically a structured grid, but defined as an unstructured one.
    # Based on the structured.jl example.
    const Ni, Nj, Nk = 40, 50, 20
    const dims = (Ni, Nj, Nk)
    const Npts = prod(dims)

    # Create points and point data.
    pts_ijk = Array(FloatType, 3, Ni, Nj, Nk)
    pdata_ijk = Array(FloatType, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts_ijk[1, i, j, k] = r * cos(th)
        pts_ijk[2, i, j, k] = r * sin(th)
        pts_ijk[3, i, j, k] = (k - 1)/(Nk - 1)
        pdata_ijk[i, j, k] = i*i + k*sqrt(j)
    end

    # Create cells (all hexahedrons in this case) and cell data.
    const celltype = VTKCellTypes.VTK_HEXAHEDRON
    cells = MeshCell[]
    cdata = FloatType[]

    for k = 2:Nk, j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = Array(Int32, 8)
        inds[1] = sub2ind(dims, i-1, j-1, k-1)
        inds[2] = sub2ind(dims, i  , j-1, k-1)
        inds[3] = sub2ind(dims, i  , j  , k-1)
        inds[4] = sub2ind(dims, i-1, j  , k-1)
        inds[5] = sub2ind(dims, i-1, j-1, k  )
        inds[6] = sub2ind(dims, i  , j-1, k  )
        inds[7] = sub2ind(dims, i  , j  , k  )
        inds[8] = sub2ind(dims, i-1, j  , k  )

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j*k)
    end

    pts = reshape(pts_ijk, 3, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

# 2D mesh
function mesh_data(::Val{2})
    const Ni, Nj = 40, 50
    const dims = (Ni, Nj)
    const Npts = prod(dims)

    # Create points and point data.
    pts_ijk = Array(FloatType, 2, Ni, Nj)
    pdata_ijk = Array(FloatType, Ni, Nj)

    for j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts_ijk[1, i, j] = r * cos(th)
        pts_ijk[2, i, j] = r * sin(th)
        pdata_ijk[i, j] = i*i + sqrt(j)
    end

    # Create cells (all quads in this case) and cell data.
    const celltype = VTKCellTypes.VTK_QUAD
    cells = MeshCell[]
    cdata = FloatType[]

    for j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = Array(Int32, 4)
        inds[1] = sub2ind(dims, i-1, j-1)
        inds[2] = sub2ind(dims, i  , j-1)
        inds[3] = sub2ind(dims, i  , j  )
        inds[4] = sub2ind(dims, i-1, j  )

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j)
    end

    pts = reshape(pts_ijk, 2, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

# 1D mesh
function mesh_data(::Val{1})
    const Ni = 40
    const Npts = Ni

    # Create points and point data.
    pts_ijk = Array(FloatType, 1, Ni)
    pdata_ijk = Array(FloatType, Ni)

    for i = 1:Ni
        pts_ijk[1, i] = (i-1)^2 / (Ni-1)^2
        pdata_ijk[i] = i*i
    end

    # Create cells (all lines in this case) and cell data.
    const celltype = VTKCellTypes.VTK_LINE
    cells = MeshCell[]
    cdata = FloatType[]

    for i = 2:Ni
        # Define connectivity of cell.
        inds = Array(Int32, 2)
        inds[1] = i-1
        inds[2] = i

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i)
    end

    pts = reshape(pts_ijk, 1, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

function main()
    outfiles = UTF8String[]
    for dim in 1:3
        pts, cells, pdata, cdata = mesh_data(Val{dim}())

        @time begin
            # Initialise new vtu file (unstructured grid).
            vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", pts, cells)

            # This is also accepted in 3D:
            # vtk = vtk_grid(vtk_filename_noext, pts[1, :], pts[2, :], pts[3, :],
            #                cells)

            # Add some point and cell data.
            vtk_point_data(vtk, pdata, "my_point_data")
            vtk_cell_data(vtk, cdata, "my_cell_data")

            # Save and close vtk file.
            append!(outfiles, vtk_save(vtk))
        end
    end

    println("Saved:  ", join(outfiles, "  "))
    return outfiles::Vector{UTF8String}
end

main()
