"""
    vtk_write_array(filename, arrays, labels)
    vtk_write_array(filename, array, label="array")

Write a Julia array to a VTK image data file (.vti).

Useful for general visualisation of arrays.
The input can be a 2D or 3D array.

"""
function vtk_write_array(filename::AbstractString,
                         arrays::AbstractVector{A},
                         labels::AbstractVector{String}) where {T<:Real,N,A<:AbstractArray{T,N}}
    if !(2 <= N <= 3)
        throw(ArgumentError("Input should be a 2D or 3D array."))
    end
    if length(arrays) != length(labels)
      throw(ArgumentError("Number of arrays and labels must be equal."))
    end
    vtkfile = vtk_grid(filename, size(arrays[1])...)
    for (array, label) in Iterators.zip(arrays, labels)
      vtk_point_data(vtkfile, array, label)
    end
    vtk_save(vtkfile)
end

function vtk_write_array(filename::AbstractString,
                         array::AbstractArray{T},
                         label::AbstractString="array") where T <: Real
    vtk_write_array(filename, [array], [label])
end
