# Variant of vtk_grid with 4-D array xyz.
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString, xyz::AbstractArray{T,4};
        compress::Bool=true, append::Bool=true, extent=nothing)

    Ncomp, Ni, Nj, Nk = size(xyz)
    @assert Ncomp == 3  # three components (x, y, z)

    xvtk = XMLDocument()

    Npts = Ni*Nj*Nk
    Ncls = (Ni - 1) * (Nj - 1) * (Nk - 1)

    ext = extent_attribute(Ni, Nj, Nk, extent)

    vtk = DatasetFile(xvtk, filename_noext*".vts", "StructuredGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # StructuredGrid node
    xGrid = new_child(xroot, vtk.gridType_str)
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


# Variant of vtk_grid with 3-D arrays x, y, z.
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractArray{T,3}, y::AbstractArray{T,3}, z::AbstractArray{T,3};
        compress::Bool=true, append::Bool=true, extent=nothing)
    @assert size(x) == size(y) == size(z)
    Ni, Nj, Nk = size(x)
    xyz = Array(T, 3, Ni, Nj, Nk)
    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        xyz[1, i, j, k] = x[i, j, k]
        xyz[2, i, j, k] = y[i, j, k]
        xyz[3, i, j, k] = z[i, j, k]
    end
    return vtk_grid(filename_noext, xyz;
                    compress=compress, append=append,
                    extent=extent)::DatasetFile
end
