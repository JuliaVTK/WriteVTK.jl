using Base.Threads: @spawn
using WriteVTK
using Test

function pvtk_unstructured()
    # Suppose that the mesh is made of 5 points:
    cells = [
        MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
        MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5]),
    ]
    x = [0.95, 0.16, 0.07, 0.21, 0.60]
    y = [0.32, 0.55, 0.87, 0.12, 0.85]
    vtufile = "simulation/simulation_1.vtu"
    rm(vtufile, force = true)
    @time outfiles = pvtk_grid("simulation", x, y, cells; part = 1, nparts = 1) do pvtk # 2D
        pvtk["Pressure"] = x
        pvtk["Processor"] = [1,2]
        pvtk["Temperature", VTKPointData()] = y
        pvtk["Id", VTKCellData()] = [2, 1]
    end
    @test isfile(vtufile)
    @test vtufile ∈ outfiles
    println("Saved:  ", join(outfiles, "  "))
    @test WriteVTK._serial_filename(3, 100, "prefix", ".ext") == "prefix_003.ext"
    outfiles
end

function make_structured_partition()
    Ns = (10, 15, 3)
    xp = (1:5, 5:10)  # NOTE: overlapping is required by VTK
    yp = (1:3, 3:12, 12:15)
    zp = (1:3, )
    extents = collect(Iterators.product(xp, yp, zp))
    Ns, extents
end

function pvtk_imagedata()
    Ns, extents = make_structured_partition()
    xs_whole = map(N -> range(-1; step = 0.2, length = N), Ns)  # full grid
    nparts = length(extents)  # number of "processes"
    filenames = Vector{Vector{String}}(undef, nparts)
    @sync for (n, extent) ∈ enumerate(extents)
        @spawn begin
            xs = getindex.(xs_whole, extent)  # local grid
            point_data = map(x -> +(x...), Iterators.product(xs...))
            processid = fill(n, length.(xs) .- 1)  # cell data
            filenames[n] = pvtk_grid(
                "pimage", xs...;
                part = n, extents = extents,
                append = false, compress = false,
            ) do vtk
                vtk["point_data"] = point_data
                vtk["process_id"] = processid
            end
        end
    end
    collect(Iterators.flatten(filenames))
end

function main()
    vcat(
        pvtk_unstructured(),
        pvtk_imagedata(),
    )
end

main()
