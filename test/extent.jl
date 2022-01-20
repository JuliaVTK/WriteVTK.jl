using Test
using WriteVTK

@testset "Extent" begin
    @testset "N = 2" begin
        Ns = (6, 8)
        ext = (1:6, 3:10)
        @test WriteVTK.extent_attribute(Ns) == "0 5 0 7 0 0"
        @test WriteVTK.extent_attribute(ext) == "0 5 2 9 0 0"
    end

    @testset "N = 3" begin
        Ns = (6, 8, 42)
        ext = (1:6, 1:8, 1:3)
        ext = (1:6, 1:8, 2:43)
        @test WriteVTK.extent_attribute(ext) == "0 5 0 7 1 42"
        @test WriteVTK.extent_attribute(Ns) == "0 5 0 7 0 41"
    end

    @testset "N = 4" begin
        Ns = (3, 4, 5, 6)
        @test_throws ArgumentError WriteVTK.extent_attribute(Ns)
    end
end
