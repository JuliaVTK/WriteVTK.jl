# TODO
# - Document extent option.

# extent should be a vector of integers of length 6.
function vtk_grid(
        filename_noext::AbstractString,
        Nx::Integer, Ny::Integer, Nz::Integer;
        origin=[0.0, 0.0, 0.0], spacing=[1.0, 1.0, 1.0],
        compress::Bool=true, append::Bool=true, extent=nothing)
    xvtk = XMLDocument()

    Npts = Nx*Ny*Nz
    Ncls = (Nx - 1) * (Ny - 1) * (Nz - 1)

    ext = extent_attribute(Nx, Ny, Nz, extent)

    vtk = DatasetFile(xvtk, filename_noext*".vti", "ImageData",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # ImageData node
    xGrid = new_child(xroot, vtk.gridType_str)
    set_attribute(xGrid, "WholeExtent", ext)

    origin_str = string(origin[1], " ", origin[2], " ", origin[3])
    spacing_str = string(spacing[1], " ", spacing[2], " ", spacing[3])
    set_attribute(xGrid, "Origin", origin_str)
    set_attribute(xGrid, "Spacing", spacing_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    return vtk::DatasetFile
end
