using Test
using WriteVTK

@testset "Extent" begin
    @testset "N = 2" begin
        Ns = (6, 8)
        ext = (1:6, 3:10)
        @test_throws DimensionMismatch WriteVTK.extent_attribute(Ns .- 1, ext)
        @test WriteVTK.extent_attribute(Ns, ext) == "1 6 3 10 0 0"
        @test WriteVTK.extent_attribute(Ns) == "0 5 0 7 0 0"
    end

    @testset "N = 3" begin
        Ns = (6, 8, 42)
        ext = (0:5, 0:7, 0:2)
        @test_throws DimensionMismatch WriteVTK.extent_attribute(Ns, ext)
        ext = (0:5, 0:7, 1:42)
        @test WriteVTK.extent_attribute(Ns, ext) == "0 5 0 7 1 42"
        @test WriteVTK.extent_attribute(Ns) == "0 5 0 7 0 41"
    end

    @testset "N = 4" begin
        Ns = (3, 4, 5, 6)
        ext = Base.OneTo.(Ns)
        @test_throws ArgumentError WriteVTK.extent_attribute(Ns, ext)
    end
end
