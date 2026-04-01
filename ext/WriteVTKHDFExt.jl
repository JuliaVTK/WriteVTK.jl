module WriteVTKHDFExt

    using HDF5
    import WriteVTK: vtk_grid, num_points
    using WriteVTK: VTKHDF5, VTKHDFUnstructuredGrid, VTKUnstructuredGrid
    using WriteVTK: UnstructuredCoord, CellVector
    
    __init__() = println("Pkg extension loaded!")
    
    


end