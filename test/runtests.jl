#!/usr/bin/env julia

using WriteVTK
using Test: @test
using SHA: sha1

const tests = ["multiblock.jl",
               "rectilinear.jl",
               "imagedata.jl",
               "structured.jl",
               "unstructured.jl",
               "pvdCollection.jl",
               "array.jl"]

# Only toggle to generate new checksums, if new tests are added.
const OVERWRITE_CHECKSUMS = false
const checksums_file = joinpath(dirname(@__FILE__), "checksums.sha1")
const checksum_list = read(checksums_file, String)

if OVERWRITE_CHECKSUMS
    csio = open(checksums_file, "w")
end

const EXECDIR = "output"
mkpath(EXECDIR)
cd(EXECDIR)

# Run the test scripts.
for test in tests
    println("TEST (first run): ", test)
    outfiles = evalfile(test)::Vector{String}

    # Check that the generated files match the stored checksums.
    for file in outfiles
        sha_str = bytes2hex(open(sha1, file)) * "  $file\n"
        if OVERWRITE_CHECKSUMS
            write(csio, sha_str)
        else
            # Returns `nothing` if string is not found.
            @test findfirst(sha_str, checksum_list) != nothing
        end
    end
    println()
end

OVERWRITE_CHECKSUMS && close(csio)

println("="^60, "\n")

# Run the tests again, just to measure the time and allocations once all the
# functions have already been compiled.
for test in tests
    println("TEST (second run): ", test)
    outfiles = evalfile(test)::Vector{String}
    println()
end

