# Included in WriteVTK.jl.

# Variant of vtk_grid with 4-D array xyz.
function vtk_grid{T<:FloatingPoint}(
        filename_noext::AbstractString, xyz::Array{T,4};
        compress::Bool=true, append::Bool=true)

    Ncomp, Ni, Nj, Nk = size(xyz)
    @assert Ncomp == 3  # three components (x, y, z)

    xvtk = XMLDocument()

    Npts = Ni*Nj*Nk
    Ncls = (Ni - 1) * (Nj - 1) * (Nk - 1)
    vtk = DatasetFile(xvtk, filename_noext*".vts", "StructuredGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # StructuredGrid node
    xGrid = new_child(xroot, vtk.gridType_str)
    extent = "1 $Ni 1 $Nj 1 $Nk"
    set_attribute(xGrid, "WholeExtent", extent)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", extent)

    # Points node
    xPoints = new_child(xPiece, "Points")

    # DataArray node
    data_to_xml(vtk, xPoints, xyz, "Points", 3)

    return vtk::DatasetFile
end


# Variant of vtk_grid with 3-D arrays x, y, z.
function vtk_grid{T<:FloatingPoint}(
        filename_noext::AbstractString,
        x::Array{T,3}, y::Array{T,3}, z::Array{T,3};
        compress::Bool=true, append::Bool=true)
    @assert size(x) == size(y) == size(z)
    Ni, Nj, Nk = size(x)
    xyz = Array(T, 3, Ni, Nj, Nk)
    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        xyz[1, i, j, k] = x[i, j, k]
        xyz[2, i, j, k] = y[i, j, k]
        xyz[3, i, j, k] = z[i, j, k]
    end
    return vtk_grid(filename_noext, xyz;
                    compress=compress, append=append)::DatasetFile
end
