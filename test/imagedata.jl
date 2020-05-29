#!/usr/bin/env julia

# Create image data VTK file.
# This corresponds to a rectilinear grid with uniform spacing in each direction.

using WriteVTK
const FloatType = Float32
const vtk_filename_noext = "imagedata"

function main()
    # Define grid.
    Ni, Nj, Nk = 20, 30, 40

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

    # These are all optional:
    extent = [1, Ni, 1, Nj, 1, Nk] .+ 42
    origin = [1.2, 4.3, -3.1]
    spacing = [0.1, 0.5, 1.2]

    # Initialise new vti file (image data).
    @time outfiles = vtk_grid(vtk_filename_noext, Ni, Nj, Nk, extent=extent,
                              origin=origin, spacing=spacing) do vtk
        # Add data.
        vtk["p_values"] = p
        vtk["q_values"] = q
        vtk["myVector"] = vec
        vtk["myCellData"] = cdata

        # Field data
        vtk["time"] = 4.2
        vtk["field_tuple"] =
            ([2.0, 3.0, 4.0], [1.0, 2.0, 3.0])  # 2 components, 3 "tuples"
        vtk["field_matrix", VTKFieldData()] =
            (1:4) * (2:5)'  # 1 component, 16 "tuples"
    end

    # Test 2D dataset
    @time outfiles_2D = vtk_grid(vtk_filename_noext * "_2D", Ni, Nj,
                                 # extent=extent[1:2],  # doesn't work for now (TODO)
                                 origin=origin[1:2], spacing=spacing[1:2]) do vtk
        vtk["p_values"] = p[:, :, 1]
        vtk["myVector"] = vec[:, :, :, 1]
        vtk["myCellData"] = cdata[:, :, 1]
    end

    append!(outfiles, outfiles_2D)

    # Test specifying coordinates using LinRange
    for D in (2, 3)  # test 2D and 3D datasets
        suffix = D == 2 ? "_2D" : ""
        let xyz = (LinRange(0., 5., Ni),
                   LinRange(1., 3., Nj),
                   LinRange(2., 6., Nk))
            coords = xyz[1:D]
            @time saved = vtk_grid(vtk_filename_noext * "_LinRange" * suffix,
                                   coords, compress=true) do vtk
                vtk["myVector"] = D == 3 ? vec : view(vec, 1:2, :, :, 1)
                vtk["myCellData"] = D == 3 ? cdata : view(cdata, :, :, 1)
            end
            append!(outfiles, saved)
        end

        # Similar using StepRangeLen
        let xyz = (0:0.08:5, 1.2:0.05:2., 1.2:0.1:2.)
            coords = xyz[1:D]
            @time saved = vtk_grid(
                identity, vtk_filename_noext * "_StepRangeLen" * suffix, coords)
            append!(outfiles, saved)
        end
    end

    println("Saved:   ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()
