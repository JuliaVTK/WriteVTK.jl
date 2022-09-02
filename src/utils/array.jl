"""
    vtk_write_array(filename, arrays, labels)
    vtk_write_array(filename, array; label = "array")

Write Julia arrays to a VTK image data file (.vti).

Useful for general visualisation of arrays.
The input can be a 2D or 3D array.

Multiple arrays can be given as a tuple.
For instance,

    vtk_write_array(filename, (u, v), ("u", "v"))

In that case, the arrays must have the same dimensions.

"""
function vtk_write_array(filename::AbstractString,
                         arrays::NTuple{M, A},
                         labels::NTuple{M, S}) where
        {T <: Real, M, N, A <: AbstractArray{T,N}, S <: AbstractString}
    if !(2 <= N <= 3)
        throw(DimensionMismatch("input should be a 2D or 3D array."))
    end
    vtk_grid(filename, size(arrays[1])...) do vtkfile
        for (array, label) in Iterators.zip(arrays, labels)
            vtkfile[label, VTKPointData()] = array
        end
    end
end

vtk_write_array(filename::AbstractString,
                array::AbstractArray{T},
                label::AbstractString = "array") where T <: Real =
vtk_write_array(filename, (array, ), (label, ))
