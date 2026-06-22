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

function main()
    dims = (200, 100, 10)
    data = reshape(collect(Float64, 1:prod(dims)), dims)

    KiB = 1024
    MiB = 1024 * KiB
    GiB = 1024 * MiB

    @test !WriteVTK._can_compress_in_parallel(Float64[])

    # Test these expected block sizes:
    # | Input Size | Block Size | Number of Blocks |
    # |     2 MiB  |   128 KiB  |              16  |
    # |    16 MiB  |   128 KiB  |             128  |
    # |    32 MiB  |   256 KiB  |             128  |
    # |   128 MiB  |     1 MiB  |             128  |
    # |   512 MiB  |     1 MiB  |             512  |
    # |     1 GiB  |     1 MiB  |            1024  |
    # |    10 GiB  |    10 MiB  |            1024  |
    # |   100 GiB  |   100 MiB  |            1024  |
    @test WriteVTK._compression_block_size(2MiB) == 128KiB
    @test WriteVTK._compression_block_size(16MiB) == 128KiB
    @test WriteVTK._compression_block_size(32MiB) == 256KiB
    @test WriteVTK._compression_block_size(128MiB) == 1MiB
    @test WriteVTK._compression_block_size(512MiB) == 1MiB
    @test WriteVTK._compression_block_size(1GiB) == 1MiB
    @test WriteVTK._compression_block_size(10GiB) == 10MiB
    @test WriteVTK._compression_block_size(100GiB) == 100MiB

    mktempdir() do dir
        serial_files = vtk_grid(joinpath(dir, "serial_compression"), dims...;
                                compress = true) do vtk
            vtk["values"] = data
        end
        @test length(serial_files) == 1
        @test num_compressed_blocks(serial_files[1]) == 1
        @test read_values(serial_files[1], dims) == data

        parallel_files = vtk_grid(joinpath(dir, "parallel_compression"), dims...;
                         compress = true, parallel_compression = true) do vtk
            @test vtk.parallel_compression
            vtk["values"] = data
        end
        @test length(parallel_files) == 1
        field_size = sizeof(eltype(data)) * prod(dims)
        @test field_size == 1_600_000
        @test WriteVTK._compression_block_size(field_size) == 128KiB
        @test num_compressed_blocks(parallel_files[1]) == 13 # cld(1_600_000, 128KiB) == 13
        @test read_values(parallel_files[1], dims) == data
    end

    String[]
end

main()
