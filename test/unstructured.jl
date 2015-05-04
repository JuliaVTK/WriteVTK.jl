#!/usr/bin/env julia

# Create unstructured grid VTK file.

using WriteVTK
typealias FloatType Float32
const vtk_filename_noext = "unstructured"

function mesh_data()
    # This is basically a structured grid, but defined as an unstructured one.
    # Based on the structured.jl example.
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
        pts[3, i, j, k] = (k - 1)/(Nk - 1)
        pdata[i, j, k] = i*i + k*sqrt(j)
    end

    # Create cells (all hexahedrons in this case) and cell data.
    const celltype = VTKCellType.VTK_HEXAHEDRON
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

    return pts, cells, pdata, cdata
end

function main()
    pts, cells, pdata, cdata = mesh_data()

    # Initialise new vtu file (unstructured grid).
    vtk = vtk_grid(vtk_filename_noext, pts, cells)

    # Add some point and cell data.
    vtk_point_data(vtk, pdata, "my_point_data")
    vtk_cell_data(vtk, cdata, "my_cell_data")

    # Save and close vtk file.
    outfiles = vtk_save(vtk)
    println("Saved:   ", outfiles...)

    return outfiles::Vector{UTF8String}
end

main()
