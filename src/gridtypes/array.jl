"""
Write a Julia array to a VTK image data file (.vti).

Useful for general visualisation of arrays.
The input can be a 2D or 3D array.

"""
function vtk_write_array(filename_noext::AbstractString,
                         array::AbstractArray{T},
                         label::AbstractString="array") where T <: Real
    if !(2 <= ndims(array) <= 3)
        throw(ArgumentError("Input should be a 2D or 3D array."))
    end
    vtkfile = vtk_grid(filename_noext, size(array)...)
    vtk_point_data(vtkfile, array, label)
    vtk_save(vtkfile)
end
