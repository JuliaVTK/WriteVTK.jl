#!/usr/bin/env julia

# Create image data VTK file.
# This corresponds to a rectilinear grid with uniform spacing in each direction.

using WriteVTK
using Random: randn, MersenneTwister

function main()
    Ni, Nj, Nk = 20, 30, 40
    outfiles = String[]

    # Initialise random number generator with deterministic seed (for
    # reproducibility).
    rng = MersenneTwister(42)

    # Workaround recent improvements in randn! for arrays (Julia 1.5).
    # See issue #62 and https://github.com/JuliaLang/julia/pull/35078.
    # We avoid using the new randn! implementation for arrays, so that the
    # results don't change between Julia versions.
    data = [randn(rng) for i = 1:Ni, j = 1:Nj, k = 1:Nk]

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
