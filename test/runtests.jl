using WriteVTK
using Test: @test
using SHA: sha1

include("extent.jl")

const tests = [
    "lagrange_hexahedron.jl",
    "surface.jl",
    "polyhedron_cube.jl",
    "multiblock.jl",
    "rectilinear.jl",
    "imagedata.jl",
    "structured.jl",
    "unstructured.jl",
    "polydata.jl",
    "bezier.jl",
    "pvdCollection.jl",
    "array.jl",
    "pvtk_grid.jl",
]

# Only toggle to generate new checksums, if new tests are added.
const OVERWRITE_CHECKSUMS = parse(Bool, get(ENV, "OVERWRITE_CHECKSUMS", "false"))
const checksums_file = joinpath(dirname(@__FILE__), "checksums.sha1")
const checksum_list = read(checksums_file, String)

@show OVERWRITE_CHECKSUMS

if OVERWRITE_CHECKSUMS
    csio = open(checksums_file, "w")
end

const EXECDIR = "output"
mkpath(EXECDIR)
cd(EXECDIR)

# Run the test scripts.
for test in tests
    println("TEST (first pass): ", test)
    outfiles = evalfile(test)::Vector{String}

    # Check that the generated files match the stored checksums.
    for file in outfiles
        file = relpath(file)  # convert to path relative to the current directory (EXECDIR)
        sha_str = bytes2hex(open(sha1, file)) * "  $file\n"
        if OVERWRITE_CHECKSUMS
            write(csio, sha_str)
        else
            # Returns `nothing` if string is not found.
            @info "Verifying $file"
            @test findfirst(sha_str, checksum_list) !== nothing
        end
    end
    println()
end

OVERWRITE_CHECKSUMS && close(csio)

println("="^60, "\n")

# Run the tests again, just to measure the time and allocations once all the
# functions have already been compiled.
for test in tests
    println("TEST (second pass): ", test)
    outfiles = evalfile(test)::Vector{String}
    println()
end
