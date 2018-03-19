function vtk_grid(filename::AbstractString,
                  Nx::Integer, Ny::Integer, Nz::Integer=1;
                  origin::AbstractArray=[0.0, 0.0, 0.0],
                  spacing::AbstractArray=[1.0, 1.0, 1.0],
                  compress=true, append::Bool=true, extent=nothing)
    Npts = Nx*Ny*Nz
    Ncls = (Nx - 1) * (Ny - 1) * (Nz - 1)
    ext = extent_attribute(Nx, Ny, Nz, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(xvtk, add_extension(filename, ".vti"), "ImageData",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # ImageData node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    if length(origin) != 3
        throw(ArgumentError("origin array must have length 3"))
    elseif length(spacing) != 3
        throw(ArgumentError("spacing array must have length 3"))
    end

    origin_str = join(origin, " ")
    spacing_str = join(spacing, " ")
    set_attribute(xGrid, "Origin", origin_str)
    set_attribute(xGrid, "Spacing", spacing_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    return vtk::DatasetFile
end
