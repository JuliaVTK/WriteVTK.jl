#!/usr/bin/env julia

# Create unstructured grid VTK file.

using WriteVTK
import Compat.UTF8String
typealias FloatType Float32
const vtk_filename_noext = "unstructured"

# Like sub2ind, but specifically for 3D arrays.
mysub2ind(dims, i, j, k) = i + dims[1]*(j-1) + dims[1]*dims[2]*(k-1)

function mesh_data()
    # This is basically a structured grid, but defined as an unstructured one.
    # Based on the structured.jl example.
    const Ni, Nj, Nk = 40, 50, 20
    const dims = [Ni, Nj, Nk]
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

    pts = reshape(pts_ijk, 3, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

function main()
    pts, cells, pdata, cdata = mesh_data()

    # Initialise new vtu file (unstructured grid).
    vtk = vtk_grid(vtk_filename_noext, pts, cells)

    # NOTE
    # This is also accepted (but less efficient):
    # vtk = vtk_grid(vtk_filename_noext, pts[1, :], pts[2, :], pts[3, :], cells)

    # Add some point and cell data.
    vtk_point_data(vtk, pdata, "my_point_data")
    vtk_cell_data(vtk, cdata, "my_cell_data")

    # Save and close vtk file.
    outfiles = vtk_save(vtk)
    println("Saved:   ", outfiles...)

    return outfiles::Vector{UTF8String}
end

main()
