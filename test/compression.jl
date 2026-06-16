using WriteVTK
using CodecZlib: ZlibDecompressorStream
using Test

function vtk_compressed_data(bytes)
    io = IOBuffer(bytes)

    num_blocks = Int(read(io, WriteVTK.HeaderType))
    read(io, WriteVTK.HeaderType) # block size
    read(io, WriteVTK.HeaderType) # last block size
    block_sizes = [Int(read(io, WriteVTK.HeaderType)) for _ in 1:num_blocks]

    data = UInt8[]
    for block_size in block_sizes
        block = read(io, block_size)
        zReader = ZlibDecompressorStream(IOBuffer(block))
        append!(data, read(zReader))
        close(zReader)
    end

    data
end

function main()
    data = collect(Float64, 1:200_000)
    compression_level = 3

    @test !WriteVTK._can_compress_in_parallel(Float64[])

    data_buf = IOBuffer()
    WriteVTK.write_array(data_buf, data)
    data_bytes = take!(data_buf)

    serial_buf = IOBuffer()
    WriteVTK._write_compressed_serial(serial_buf, data, compression_level,
                                      WriteVTK.sizeof_data(data))
    @test vtk_compressed_data(take!(serial_buf)) == data_bytes

    parallel_buf = IOBuffer()
    WriteVTK._write_compressed_parallel(parallel_buf, data, compression_level)
    @test vtk_compressed_data(take!(parallel_buf)) == data_bytes

    mktempdir() do dir
        files = vtk_grid(joinpath(dir, "parallel_compression"), 2, 2, 2;
                         compress = compression_level,
                         parallel_compression = true) do vtk
            @test vtk.parallel_compression
            vtk["values"] = reshape(collect(Float64, 1:8), 2, 2, 2)
        end
        @test length(files) == 1
        @test isfile(files[1])
    end

    String[]
end

main()
