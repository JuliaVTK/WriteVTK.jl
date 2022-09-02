using WriteVTK

xs = (0:0.1:1).^2
ys = 0:0.2:4

zs = @. xs * sinpi(ys')

@time vtk_surface("surface", xs, ys, zs; compress = false, append = false) do vtk
    vtk["point_data"] = zs
    vtk["cell_data"] = @views abs2.(zs[2:end, 2:end])
end
