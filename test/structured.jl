#!/usr/bin/env julia

# Create structured grid VTK file.

using WriteVTK
import Compat: UTF8String, view
typealias FloatType Float32
const vtk_filename_noext = "structured"

function main()
    outfiles = UTF8String[]
    for dim in 2:3
        # Define grid.
        if dim == 2
            Ni, Nj, Nk = 20, 30, 1
        elseif dim == 3
            Ni, Nj, Nk = 20, 30, 40
        end

        local xyz
        if dim == 2
            xyz = zeros(FloatType, 2, Ni, Nj)
            for j = 1:Nj, i = 1:Ni
                xyz[1, i, j] = i/Ni * cos(3*pi/2 * (j-1) / (Nj-1))
                xyz[2, i, j] = i/Ni * sin(3*pi/2 * (j-1) / (Nj-1))
            end
        elseif dim == 3
            xyz = zeros(FloatType, 3, Ni, Nj, Nk)
            for k = 1:Nk, j = 1:Nj, i = 1:Ni
                xyz[1, i, j, k] = i/Ni * cos(3*pi/2 * (j-1) / (Nj-1))
                xyz[2, i, j, k] = i/Ni * sin(3*pi/2 * (j-1) / (Nj-1))
                xyz[3, i, j, k] = (k-1) / Nk
            end
        end

        # Create some scalar and vectorial data.
        q = zeros(FloatType, Ni, Nj, Nk)
        vec = zeros(FloatType, 3, Ni, Nj, Nk)

        # Just to test support for subarrays:
        p = zeros(FloatType, 2Ni, 2Nj, 2Nk)
        psub = view(p, 1:Ni, 1:Nj, 1:Nk)

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
        ext = [0, Ni-1, 0, Nj-1, 0, Nk-1]

        @time begin
            # Initialise new vts file (structured grid).
            vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", xyz; extent=ext)

            # This is also accepted:
            # vtk = vtk_grid(vtk_filename_noext, xyz[1, :], xyz[2, :]) # For 2D
            # vtk = vtk_grid(vtk_filename_noext, xyz[1, :], xyz[2, :], xyz[3, :]) # For 3D

            # Add data.
            vtk_point_data(vtk, psub, "p_values")
            vtk_point_data(vtk, q, "q_values")
            vtk_point_data(vtk, vec, "myVector")
            vtk_cell_data(vtk, cdata, "myCellData")

            # Save and close vtk file.
            append!(outfiles, vtk_save(vtk))
        end
    end # dim loop

    println("Saved:  ", join(outfiles, "  "))
    return outfiles::Vector{UTF8String}
end

main()
