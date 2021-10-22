using WriteVTK
using Test

function main()
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

main()
