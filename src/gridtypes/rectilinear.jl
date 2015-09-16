# Included in WriteVTK.jl.

# TODO
# - Document extent option.

# extent should be a vector of integers of length 6.
function vtk_grid{T<:FloatingPoint}(
        filename_noext::AbstractString,
        x::Array{T,1}, y::Array{T,1}, z::Array{T,1};
        compress::Bool=true, append::Bool=true, extent=nothing)
    xvtk = XMLDocument()

    Ni, Nj, Nk = length(x), length(y), length(z)
    Npts = Ni*Nj*Nk
    Ncls = (Ni - 1) * (Nj - 1) * (Nk - 1)

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
