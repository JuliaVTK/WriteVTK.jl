# Structured dataset coordinates can be specified using either a 4D array
# (3, Ni, Nj, Nk), or a tuple (x, y, z).
const Array4 = AbstractArray{T, 4} where T
const Array3Tuple3 = Tuple{Vararg{<:AbstractArray{T,3}, 3}} where T
const StructuredCoords = Union{Array4, Array3Tuple3}

structured_dims(xyz::Array4) = ntuple(d -> size(xyz, d + 1), 3)
structured_dims(xyz::Array3Tuple3) = size(first(xyz))

function vtk_grid(dtype::VTKStructuredGrid, filename::AbstractString,
                  xyz::StructuredCoords; extent=nothing, kwargs...)
    Ni, Nj, Nk = structured_dims(xyz)
    Npts = Ni * Nj * Nk
    Ncomp = num_components(xyz, Npts)
    Ncls = num_cells_structured(Ni, Nj, Nk)
    ext = extent_attribute(Ni, Nj, Nk, extent)

    if Ncomp != 3  # three components (x, y, z)
        msg = "coordinate array `xyz` has incorrect dimensions.\n" *
              "Expected dimensions: (3, Ni, Nj, Nk).\n" *
              "Actual dimensions: $(size(xyz))"
        throw(DimensionMismatch(msg))
    end

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # StructuredGrid node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    # Points node
    xPoints = new_child(xPiece, "Points")

    # DataArray node
    data_to_xml(vtk, xPoints, xyz, "Points", 3)

    return vtk::DatasetFile
end

# 3D variant of vtk_grid with 4D array xyz.
vtk_grid(filename::AbstractString, xyz::AbstractArray{T,4};
         kwargs...) where T =
    vtk_grid(VTKStructuredGrid(), filename, xyz; kwargs...)

# 3D variant of vtk_grid with 3D arrays x, y, z.
function vtk_grid(filename::AbstractString, x::AbstractArray{T,3},
                  y::AbstractArray{T,3}, z::AbstractArray{T,3};
                  kwargs...) where T
    if !(size(x) == size(y) == size(z))
        throw(DimensionMismatch("size of x, y and z arrays must be the same."))
    end
    vtk_grid(VTKStructuredGrid(), filename, (x, y, z); kwargs...)
end

# 2D variant of vtk_grid with 3D array xy
function vtk_grid(filename::AbstractString, xy::AbstractArray{T,3};
                  kwargs...) where T
    Ncomp, Ni, Nj = size(xy)
    if Ncomp != 2
        msg = "coordinate array `xy` has incorrect dimensions.\n" *
              "Expected dimensions: (2, Ni, Nj).\n" *
              "Actual dimensions: $(size(xy))"
        throw(DimensionMismatch(msg))
    end
    xyz = (
        reshape(view(xy, 1, :, :), Ni, Nj, 1),
        reshape(view(xy, 2, :, :), Ni, Nj, 1),
        zeros(T, Ni, Nj, 1),  # TODO lazy?
    )
    vtk_grid(VTKStructuredGrid(), filename, xyz; kwargs...)
end


# 2D variant of vtk_grid with 2D arrays x, y.
function vtk_grid(filename::AbstractString, x::AbstractArray{T,2},
                  y::AbstractArray{T,2}; kwargs...) where T
    if size(x) != size(y)
        throw(DimensionMismatch("size of x and y arrays must be the same."))
    end
    Ni, Nj = size(x)
    xyz = (
        reshape(x, :, :, 1),
        reshape(y, :, :, 1),
        zeros(T, Ni, Nj, 1),  # TODO lazy?
    )
    vtk_grid(VTKStructuredGrid(), filename, xyz; kwargs...)
end
