#!/usr/bin/env julia

# Create rectilinear grid VTK file.

using WriteVTK
import Compat.UTF8String
typealias FloatType Float32
const vtk_filename_noext = "rectilinear"

function main()
    outfiles = UTF8String[]
    for dim in 2:3
        # Define grid.
        if dim == 2
            Ni, Nj, Nk = 20, 30, 1
        elseif dim == 3
            Ni, Nj, Nk = 20, 30, 40
        end

        x = zeros(FloatType, Ni)
        y = zeros(FloatType, Nj)
        z = zeros(FloatType, Nk)

        [x[i] = i*i/Ni/Ni for i = 1:Ni]
        [y[j] = sqrt(j/Nj) for j = 1:Nj]
        [z[k] = k/Nk for k = 1:Nk]

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
        # Note that in structured grids, the cells are the hexahedra (3D) or quads (2D)
        # formed between grid points.
        local cdata
        if dim == 2
            cdata = zeros(FloatType, Ni-1, Nj-1)
            for j = 1:Nj-1, i = 1:Ni-1
                cdata[i, j] = 2i + 20 * sin(3*pi * (j-1) / (Nj-2))
            end
        elseif dim == 3
            cdata = zeros(FloatType, Ni-1, Nj-1, Nk-1)
            for k = 1:Nk-1, j = 1:Nj-1, i = 1:Ni-1
                cdata[i, j, k] = 2i + 3k * sin(3*pi * (j-1) / (Nj-2))
            end
        end

        # Test extents (this is optional!!)
        ext = [0, Ni-1, 0, Nj-1, 0, Nk-1] + 42

        # Initialise new vtr file (rectilinear grid).
        local vtk
        if dim == 2
            vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", x, y   ; extent=ext)
        elseif dim == 3
            vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", x, y, z; extent=ext)
        end

        # Add data.
        vtk_point_data(vtk, p, "p_values")
        vtk_point_data(vtk, q, "q_values")
        vtk_point_data(vtk, vec, "myVector")
        vtk_cell_data(vtk, cdata, "myCellData")

        # Save and close vtk file.
        append!(outfiles, vtk_save(vtk))

    end # dim loop

    println("Saved:", [" "^3 * s for s in outfiles]...)
    return outfiles::Vector{UTF8String}
end

main()
