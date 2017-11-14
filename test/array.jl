#!/usr/bin/env julia

# Create image data VTK file.
# This corresponds to a rectilinear grid with uniform spacing in each direction.

using WriteVTK

function main()
    Ni, Nj, Nk = 20, 30, 40
    outfiles = String[]

    # Initialise random number generator with deterministic seed (for
    # reproducibility).
    rng = MersenneTwister(42)
    data = randn(rng, Ni, Nj, Nk)

    # Write 2D and 3D arrays.
    append!(outfiles, vtk_write_array("arraydata_2D", data[:, :, 1], "array2D"))
    append!(outfiles, vtk_write_array("arraydata_3D", data, "array3D"))

    println("Saved:  ", join(outfiles, "  "))

    return outfiles
end

main()
