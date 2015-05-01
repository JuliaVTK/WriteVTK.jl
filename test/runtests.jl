using WriteVTK
using Base.Test

# Run the test scripts.
tests = ["./rectilinear.jl", "./structured.jl", "./multiblock.jl"]

checksum_list = readall("./checksums.sha1")

for test in tests
    outfiles = evalfile(test)::Vector{UTF8String}

    # Check that the generated files match the stored checksums.
    for file in outfiles
        sha = readall(`sha1sum $file`)
        cmp = search(checksum_list, sha)  # returns 0:-1 if string is not found
        @test cmp != 0:-1
    end
end

