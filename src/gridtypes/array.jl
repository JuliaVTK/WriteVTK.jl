function vtk_write_array{T<:Number}(filename_noext::AbstractString,
                                    array::AbstractArray{T,3},
                                    property::AbstractString="array")
    vtkfile = vtk_grid(filename_noext, size(array)...)
    vtk_point_data(vtkfile, array, property)
    vtk_save(vtkfile)
end
