# Included in WriteVTK.jl.

immutable StructuredFile <: DatasetFile
    xdoc::XMLDocument
    path::UTF8String
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (or written inline, base64-encoded?)
    buf::IOBuffer       # Buffer with appended data.
    function StructuredFile(xdoc, path, Npts, compressed, appended)
        gridType_str = "StructuredGrid"
        if appended
            buf = IOBuffer()
        else
            buf = IOBuffer(0)
            close(buf)
        end
        return new(xdoc, path, gridType_str, Npts, compressed,
                   appended, buf)
    end
end


# Variant of vtk_grid with 4-D array xyz.
function vtk_grid{T<:FloatingPoint}(
        filename_noext::AbstractString, xyz::Array{T,4};
        compress::Bool=true, append::Bool=true)

    Ncomp, Ni, Nj, Nk = size(xyz)
    @assert Ncomp == 3  # three components (x, y, z)

    xvtk = XMLDocument()

    Npts = Ni*Nj*Nk
    vtk = StructuredFile(xvtk, filename_noext*".vts", Npts,
                         compress, append)

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
    data_to_xml(vtk, xPoints, xyz, 3, "Points")

    return vtk::StructuredFile
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
    return vtk_grid(filename_noext, xyz; compress=compress, append=append)
end


# Multiblock variant of vtk_grid, with 4-D array xyz.
function vtk_grid{T<:FloatingPoint}(
        vtm::MultiblockFile, xyz::Array{T,4};
        compress::Bool=true, append::Bool=true)
    path_base = splitext(vtm.path)[1]
    vtkFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtkFilename_noext, xyz; compress=compress, append=append)
    multiblock_add_block(vtm, vtk)
    return vtk::DatasetFile
end


# Multiblock variant of vtk_grid, with 3-D arrays x, y, z.
function vtk_grid{T<:FloatingPoint}(
        vtm::MultiblockFile,
        x::Array{T,3}, y::Array{T,3}, z::Array{T,3};
        compress::Bool=true, append::Bool=true)
    path_base = splitext(vtm.path)[1]
    vtkFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtkFilename_noext, x, y, z; compress=compress, append=append)
    multiblock_add_block(vtm, vtk)
    return vtk::DatasetFile
end

