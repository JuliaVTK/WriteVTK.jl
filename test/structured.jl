#!/usr/bin/env julia

# Create structured grid VTK file.

using WriteVTK
typealias FloatType Float32
const vtk_filename_noext = "structured"

function main()
    # Define grid.
    const Ni, Nj, Nk = 20, 30, 40

    xyz = zeros(FloatType, 3, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        xyz[1, i, j, k] = i/Ni * cos(3*pi/2 * (j-1) / (Nj-1))
        xyz[2, i, j, k] = i/Ni * sin(3*pi/2 * (j-1) / (Nj-1))
        xyz[3, i, j, k] = (k-1) / Nk
    end

    # Create some scalar and vectorial data.
    p = zeros(FloatType, Ni, Nj, Nk)
    q = zeros(FloatType, Ni, Nj, Nk)
    vec = zeros(FloatType, 3, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        p[i, j, k] = i*i + k
        q[i, j, k] = k*sqrt(j)
        vec[1, i, j, k] = i
        vec[2, i, j, k] = j
        vec[3, i, j, k] = k
    end

    # Create some scalar data at grid cells.
    # Note that in structured grids, the cells are the hexahedra formed between
    # grid points.
    cdata = zeros(FloatType, Ni-1, Nj-1, Nk-1)
    for k = 1:Nk-1, j = 1:Nj-1, i = 1:Ni-1
        cdata[i, j, k] = 2i + 3k * sin(3*pi * (j-1) / (Nj-2))
    end

    # Initialise new vts file (structured grid).
    vtk = vtk_grid(vtk_filename_noext, xyz)

    # This is also accepted:
    # vtk = vtk_grid(vtk_filename_noext, xyz[1, :], xyz[2, :], xyz[3, :])

    # Add data.
    vtk_point_data(vtk, p, "p_values")
    vtk_point_data(vtk, q, "q_values")
    vtk_point_data(vtk, vec, "myVector")
    vtk_cell_data(vtk, cdata, "myCellData")

    # Save and close vtk file.
    outfiles = vtk_save(vtk)
    println("Saved:   ", outfiles...)

    return outfiles::Vector{UTF8String}
end

main()
