using WriteVTK

function main()
   # Suppose that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5])]
  x=rand(5)
  y=rand(5)

  layout=WriteVTK.PVTKLayout(1,1)
  @time pvtk = pvtk_grid(layout,"simulation", x, y, cells) # 2D
  pvtk["Pressure"] = x
  pvtk["Processor"] = rand(2)
  @time vtk_save(pvtk)
end
main()
