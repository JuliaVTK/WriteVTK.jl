#!/usr/bin/env julia

using WriteVTK
typealias FloatType Float32
const vtk_filename_noext = "collection"

function main()
    # Define grid.
    const Ni, Nj, Nk, Nt = 20, 30, 40, 4

    x = zeros(FloatType, Ni)
    y = zeros(FloatType, Nj)
    z = zeros(FloatType, Nk)

    [x[i] = i*i/Ni/Ni for i = 1:Ni]
    [y[j] = sqrt(j/Nj) for j = 1:Nj]
    [z[k] = k/Nk for k = 1:Nk]

    # Create some scalar and vectorial data that decays exponentially in
    # time
    p = zeros(FloatType, Ni, Nj, Nk, Nt)
    q = zeros(FloatType, Ni, Nj, Nk, Nt)
    vec = zeros(FloatType, 3, Ni, Nj, Nk, Nt)

    for t = 1:Nt, k = 1:Nk, j = 1:Nj, i = 1:Ni
        p[i, j, k, t] = exp(-t)*(i*i + k)
        q[i, j, k, t] = exp(-t)*k*sqrt(j)
        vec[1, i, j, k] = exp(-t)*i
        vec[2, i, j, k] = exp(-t)*j
        vec[3, i, j, k] = exp(-t)*k
    end

    # Create some scalar data at grid cells.
    # Note that in structured grids, the cells are the hexahedra formed between
    # grid points.
    cdata = zeros(FloatType, Ni-1, Nj-1, Nk-1, Nt)
    for t = 1:Nt, k = 1:Nk-1, j = 1:Nj-1, i = 1:Ni-1
        cdata[i, j, k,t] = exp(-t)*(2i + 3k * sin(3*pi * (j-1) / (Nj-2)))
    end

    # Test extents (this is optional!!)
    ext = [0, Ni-1, 0, Nj-1, 0, Nk-1] + 42

    # Initialise pvd container file
    pvd = paraview_collection(vtk_filename_noext)

    # Create files for each time-step and add them to the collection
    vtk = []
    for it = 0:Nt-1
      # vtk = vtk_grid(string(vtk_filename_noext,@sprintf("_%02i",it)),x,y,z;extent=ext)
      vtk = vtk_grid(@sprintf("%s_%02i", vtk_filename_noext, it), x, y, z;
                     extent=ext)
      # Add data for current time-step
      vtk_point_data(vtk, p[:,:,:,it+1], "p_values")
      vtk_point_data(vtk, q[:,:,:,it+1], "q_values")
      vtk_point_data(vtk, vec[:,:,:,:,it+1], "myVector")
      vtk_cell_data(vtk, cdata[:,:,:,it+1], "myCellData")
      vtk_save(vtk)
      collection_add_timestep(pvd, vtk, Float64(it+1))
    end

    # Save and close vtk file.
    outfiles = vtk_save(pvd)
    println("Saved:", [" "^3 * s for s in outfiles]...)

    return outfiles::Vector{UTF8String}
end

main()

