#!/usr/bin/env julia

# Create image data VTK file.
# This corresponds to a rectilinear grid with uniform spacing in each direction.

using WriteVTK
using StableRNGs: StableRNG

function main()
    Ni, Nj, Nk = 20, 30, 40
    outfiles = String[]

    # Initialise random number generator with deterministic seed (for
    # reproducibility).
    rng = StableRNG(42)

    data = (2.0*rand(rng, Ni, Nj, Nk)) .- 1.0

    # Write 2D and 3D arrays.
    @time begin
        append!(outfiles,
                vtk_write_array("arraydata_2D", data[:, :, 1], "array2D"))
        append!(outfiles,
                vtk_write_array("arraydata_3D", data, "array3D"))
        append!(outfiles,
                vtk_write_array("arrays", (data, 2 .* data), ("A", "B")))
    end

    println("Saved:  ", join(outfiles, "  "))

    return outfiles
end

main()
