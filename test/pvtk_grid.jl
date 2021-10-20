using WriteVTK

function main()
   # Suppose that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5])]
  x=rand(5)
  y=rand(5)

  @time pvtk = pvtk_grid(
    "simulation", x, y, cells;
    pvtkargs=[:part=>1,:nparts=>1]) # 2D
  pvtk["Pressure"] = x
  pvtk["Processor"] = rand(2)
  @time outfiles = vtk_save(pvtk)
  println("Saved:  ", join(outfiles, "  "))
  outfiles
end
main()
