#!/usr/bin/env julia

using WriteVTK
using Base.Test

tests = ["multiblock.jl",
         "rectilinear.jl",
         "structured.jl",
         "unstructured.jl"]

# Only toggle to generate new checksums, if new tests are added.
OVERWRITE_CHECKSUMS = false
checksums_file = "checksums.sha1"

checksum_list = readall(checksums_file)

if OVERWRITE_CHECKSUMS
    csio = open(checksums_file, "w")
end

# Run the test scripts.
for test in tests
    println("TEST (first run): " * test)
    @time outfiles = evalfile(test)::Vector{UTF8String}

    # Check that the generated files match the stored checksums.
    for file in outfiles
        sha = readall(`sha1sum $file`)
        if OVERWRITE_CHECKSUMS
            write(csio, sha)
        else
            # Returns 0:-1 if string is not found.
            cmp = search(checksum_list, sha)
            @test cmp != 0:-1
        end
    end
    println()
end

OVERWRITE_CHECKSUMS && close(csio)

println("="^60 * "\n")

# Run the tests again, just to measure the time and allocations once all the
# functions have already been compiled.
for test in tests
    println("TEST (second run): " * test)
    @time outfiles = evalfile(test)::Vector{UTF8String}
    println()
end

