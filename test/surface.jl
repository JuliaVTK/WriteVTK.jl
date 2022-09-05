using WriteVTK
using Test

xs = (0:0.1:1).^2
ys = 0:0.2:4

zs = @. xs * sinpi(ys')

files = String[]

@test_throws DimensionMismatch vtk_surface("will_fail", xs, [0.3, 0.4], zs)

let
    @time output = let
        vtk = vtk_surface("surface_basic", xs, ys, zs)
        vtk_save(vtk)
    end
    append!(files, output)
end

let
    @time output = vtk_surface(
            "surface", xs, ys, zs;
            compress = false, append = false,
        ) do vtk
        vtk["point_data"] = zs
        vtk["cell_data"] = @views abs2.(zs[2:end, 2:end])
    end
    append!(files, output)
end

files
