#!/usr/bin/env julia

# Create image data VTK file.
# This corresponds to a rectilinear grid with uniform spacing in each direction.

using WriteVTK
using StableRNGs: StableRNG

# Version of randn that is stable across different julia versions
# Ref: https://github.com/DEShawResearch/random123/blob/9545ff6413f258be2f04c1d319d99aaef7521150/include/Random123/boxmuller.hpp
function my_randn(rng::StableRNG, dims::Integer...)
    # Box–Muller transform
    u01 = rand(rng, UInt64, dims...) .* (2.0^-64) .+ (2.0^-65)
    uneg11 = rand(rng, Int64, dims...) .* (2.0^-63) .+ (2.0^-64)
    sqrt.(-2 .* log.(u01)) .* cospi.(uneg11)
end

function main()
    Ni, Nj, Nk = 20, 30, 40
    outfiles = String[]

    # Initialise random number generator with deterministic seed (for
    # reproducibility).
    rng = StableRNG(42)

    data = my_randn(rng, Ni, Nj, Nk)

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
