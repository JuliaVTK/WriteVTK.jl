function vtk_grid(filename::AbstractString,
                  Nx::Integer, Ny::Integer, Nz::Integer=1;
                  origin::AbstractArray=[0.0, 0.0, 0.0],
                  spacing::AbstractArray=[1.0, 1.0, 1.0],
                  compress=true, append::Bool=true, extent=nothing)
    Npts = Nx*Ny*Nz
    Ncls = num_cells_structured(Nx, Ny, Nz)
    ext = extent_attribute(Nx, Ny, Nz, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(xvtk, add_extension(filename, ".vti"), "ImageData",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # ImageData node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    No = length(origin)
    Ns = length(spacing)

    if No > 3
        throw(ArgumentError("origin array must have length <= 3"))
    elseif Ns > 3
        throw(ArgumentError("spacing array must have length <= 3"))
    end

    origin_str = join(origin, " ")
    spacing_str = join(spacing, " ")

    while No != 3
        # Fill additional dimensions (e.g. the z dimension if 2D grid)
        origin_str *= (" 0.0")
        No += 1
    end

    while Ns != 3
        spacing_str *= (" 1.0")
        Ns += 1
    end

    set_attribute(xGrid, "Origin", origin_str)
    set_attribute(xGrid, "Spacing", spacing_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    return vtk::DatasetFile
end
