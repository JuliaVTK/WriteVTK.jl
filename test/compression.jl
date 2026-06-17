using WriteVTK
using ReadVTK
using Test

function read_values(filename, dims)
    vtk = ReadVTK.VTKFile(filename)
    values = ReadVTK.get_point_data(vtk)["values"]
    reshape(ReadVTK.get_data(values), dims)
end

function num_compressed_blocks(filename)
    vtk = ReadVTK.VTKFile(filename)
    values = ReadVTK.get_point_data(vtk)["values"]

    io = IOBuffer(vtk.appended_data)
    seek(io, values.offset)
    Int(read(io, WriteVTK.HeaderType))
end

# Mock the number of threads to be able to run this test on a single thread.
WriteVTK.nthreads() = 4

function main()
    dims = (200, 100, 10)
    data = reshape(collect(Float64, 1:prod(dims)), dims)
    compression_level = 3

    @test !WriteVTK._can_compress_in_parallel(Float64[])

    mktempdir() do dir
        serial_files = vtk_grid(joinpath(dir, "serial_compression"), dims...;
                                compress = compression_level) do vtk
            vtk["values"] = data
        end
        @test length(serial_files) == 1
        @test num_compressed_blocks(serial_files[1]) == 1
        @test read_values(serial_files[1], dims) == data

        parallel_files = vtk_grid(joinpath(dir, "parallel_compression"), dims...;
                         compress = compression_level,
                         parallel_compression = true) do vtk
            @test vtk.parallel_compression
            vtk["values"] = data
        end
        @test length(parallel_files) == 1
        @test num_compressed_blocks(parallel_files[1]) == 16
        @test read_values(parallel_files[1], dims) == data
    end

    String[]
end

main()
