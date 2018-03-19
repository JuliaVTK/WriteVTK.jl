function rectilinear_grid(filename::AbstractString, x::AbstractVector,
                          y::AbstractVector, z::AbstractVector;
                          compress=true, append::Bool=true,
                          extent=nothing)
    Ni, Nj, Nk = length(x), length(y), length(z)
    Npts = Ni*Nj*Nk
    Ncls = num_cells_structured(Ni, Nj, Nk)
    ext = extent_attribute(Ni, Nj, Nk, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(xvtk, add_extension(filename, ".vtr"), "RectilinearGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # RectilinearGrid node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    # Coordinates node
    xPoints = new_child(xPiece, "Coordinates")

    # DataArray node
    data_to_xml(vtk, xPoints, x, "x")
    data_to_xml(vtk, xPoints, y, "y")
    data_to_xml(vtk, xPoints, z, "z")

    return vtk::DatasetFile
end

# 3D variant
vtk_grid(filename::AbstractString, x::AbstractVector{T},
         y::AbstractVector{T}, z::AbstractVector{T}; kwargs...) where T =
    rectilinear_grid(filename, x, y, z; kwargs...)

# 2D variant
vtk_grid(filename::AbstractString, x::AbstractVector{T},
         y::AbstractVector{T}; kwargs...) where T =
    rectilinear_grid(filename, x, y, zeros(T, 1); kwargs...)
