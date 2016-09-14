# TODO
# - Document extent option.

# extent should be a vector of integers of length 6.
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractVector{T}, y::AbstractVector{T}, z::AbstractVector{T};
        compress::Bool=true, append::Bool=true, extent=nothing)
    xvtk = XMLDocument()

    Ni, Nj, Nk = length(x), length(y), length(z)
    Npts = Ni*Nj*Nk
    Ncls = num_cells_structured(Ni, Nj, Nk)

    ext = extent_attribute(Ni, Nj, Nk, extent)

    vtk = DatasetFile(xvtk, filename_noext*".vtr", "RectilinearGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # RectilinearGrid node
    xGrid = new_child(xroot, vtk.gridType_str)
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

# 2D version
vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractVector{T}, y::AbstractVector{T};
        compress::Bool=true, append::Bool=true, extent=nothing) =
    vtk_grid(filename_noext, x, y, zeros(T,1), compress=compress, append=append, extent=extent)
