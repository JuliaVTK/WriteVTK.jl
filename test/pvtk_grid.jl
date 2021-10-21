using WriteVTK
using Test

function main()
   # Suppose that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5])]
  x=[.95,.16,.07,.21,.60]
  y=[.32,.55,.87,.12,.85]
  vtufile = "simulation/simulation_1.vtu"
  rm(vtufile,force=true)
  @time pvtk = pvtk_grid("simulation", x, y, cells; part=1,nparts=1) # 2D
  pvtk["Pressure"] = x
  pvtk["Processor"] = rand(2)
  @time outfiles = vtk_save(pvtk)
  @test isfile(vtufile)
  println("Saved:  ", join(outfiles, "  "))
  outfiles
end
main()
