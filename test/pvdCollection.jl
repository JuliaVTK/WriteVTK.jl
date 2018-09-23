#!/usr/bin/env julia

using WriteVTK

using Printf: @sprintf

const FloatType = Float32
const vtk_filename_noext = "collection"

function update_point_data!(p, q, vec, time)
    E = exp(-time)
    for I in CartesianIndices(p)
        i, j, k = I[1], I[2], I[3]
        p[I] = E * (i * i + k)
        q[I] = E * k * sqrt(j)
        vec[1, i, j, k] = E * i
        vec[2, i, j, k] = E * j
        vec[3, i, j, k] = E * k
    end
    p, q, vec
end

function update_cell_data!(cdata, time)
    Nj = size(cdata, 2) + 1
    α = 3pi / (Nj - 2)
    E = exp(-time)
    for I in CartesianIndices(cdata)
        i, j, k = I[1], I[2], I[3]
        cdata[I] = E * (2i + 3k * sin(α * (j - 1)))
    end
    cdata
end

function main()
    # Define grid.
    Ni, Nj, Nk, Nt = 20, 30, 40, 4

    x = zeros(FloatType, Ni)
    y = zeros(FloatType, Nj)
    z = zeros(FloatType, Nk)

    [x[i] = i*i/Ni/Ni for i = 1:Ni]
    [y[j] = sqrt(j/Nj) for j = 1:Nj]
    [z[k] = k/Nk for k = 1:Nk]

    # Arrays for scalar and vector fields assigned to grid points.
    p = zeros(FloatType, Ni, Nj, Nk)
    q = zeros(FloatType, Ni, Nj, Nk)
    vec = zeros(FloatType, 3, Ni, Nj, Nk)

    # Scalar data assigned to grid cells.
    # Note that in structured grids, the cells are the hexahedra formed between
    # grid points.
    cdata = zeros(FloatType, Ni - 1, Nj - 1, Nk - 1)

    # Test extents (this is optional!!)
    ext = [0, Ni-1, 0, Nj-1, 0, Nk-1] .+ 42

    # Initialise pvd container file
    @time outfiles = paraview_collection(vtk_filename_noext) do pvd
        # Create files for each time-step and add them to the collection
        for it = 0:Nt-1
            vtk = vtk_grid(@sprintf("%s_%02i", vtk_filename_noext, it), x, y, z;
                           extent=ext)
            # Add data for current time-step
            update_point_data!(p, q, vec, it + 1)
            update_cell_data!(cdata, it + 1)
            vtk_point_data(vtk, p, "p_values")
            vtk_point_data(vtk, q, "q_values")
            vtk_point_data(vtk, vec, "myVector")
            vtk_cell_data(vtk, cdata, "myCellData")
            vtk_save(vtk)
            collection_add_timestep(pvd, vtk, Float64(it+1))
        end
    end
    println("Saved:  ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()

