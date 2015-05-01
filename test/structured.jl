#!/usr/bin/env julia

# Create structured grid VTK file.

using WriteVTK
typealias FloatType Float32
const vts_filename_noext = "test_structured"

function main()
    # Define grid.
    const Ni, Nj, Nk = 20, 30, 40

    x = zeros(FloatType, Ni, Nj, Nk)
    y = zeros(FloatType, Ni, Nj, Nk)
    z = zeros(FloatType, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        x[i, j, k] = i/Ni * cos(2*pi/3 * j/Nj)
        y[i, j, k] = i/Ni * sin(2*pi/3 * j/Nj)
        z[i, j, k] = k/Nk
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

    # Initialise new vts file (structured grid).
    vts = vtk_grid(vts_filename_noext, x, y, z)

    # Add data.
    vtk_point_data(vts, p, "p_values")
    vtk_point_data(vts, q, "q_values")
    vtk_point_data(vts, vec, "myVector")

    # Save and close vts file.
    filename_vts = vtk_save(vts)
    println("Saved ", filename_vts)

    return
end

main()
