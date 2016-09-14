# Variant of vtk_grid with 2-D array "points".
# Size: (dim, num_points)
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        points::AbstractMatrix{T}, cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)

    xvtk = XMLDocument()

    dim, Npts = size(points)

    # Reshape to 3D (if its not already)
    if dim == 1
        _points = zeros(3,np)
        _points[1,:] = points
    elseif dim == 2
        _points = zeros(3,np)
        _points[1:2,:] = points
    elseif dim == 3
        _points = points
    else
        throw(ArgumentError("points must be of size (dim,Npts) where dim = 1, 2 or 3 and Npts the number of points."))
    end

    Ncls = length(cells)

    vtk = DatasetFile(xvtk, filename_noext*".vtu", "UnstructuredGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # UnstructuredGrid node
    xGrid = new_child(xroot, vtk.gridType_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", vtk.Npts)
    set_attribute(xPiece, "NumberOfCells",  vtk.Ncls)

    # Points node
    xPoints = new_child(xPiece, "Points")

    # DataArray node
    data_to_xml(vtk, xPoints, _points, "Points", 3)

    # Cells node (below the Piece node)
    xCells = new_child(xPiece, "Cells")

    # Create data arrays.
    offsets = Array(Int32, Ncls)
    types = Array(UInt8, Ncls)

    Nconn = 0     # length of the connectivity array
    if Ncls >= 1  # it IS possible to have no cells
        offsets[1] = length(cells[1].connectivity)
    end

    for (n, c) in enumerate(cells)
        Npts_cell = length(c.connectivity)
        Nconn += Npts_cell
        types[n] = c.ctype.vtk_id
        if n >= 2
            offsets[n] = offsets[n-1] + Npts_cell
        end
    end

    # Create connectivity array.
    conn = Array(Int32, Nconn)
    const ONE = one(Int32)
    n = 1
    for c in cells
        for i in c.connectivity
            # We transform to zero-based indexing, required by VTK.
            conn[n] = i - ONE
            n += 1
        end
    end

    # Add arrays to the XML file (DataArray nodes).
    data_to_xml(vtk, xCells, conn,    "connectivity")
    data_to_xml(vtk, xCells, offsets, "offsets"     )
    data_to_xml(vtk, xCells, types,   "types"       )

    return vtk::DatasetFile
end

# Variant of vtk_grid with 1-D arrays x, y, z.
# Size of each array: (num_points)
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractVector{T}, y::AbstractVector{T}, z::AbstractVector{T},
        cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)
    @assert length(x) == length(y) == length(z)
    Npts = length(x)
    points = Array(T, 3, Npts)
    for n = 1:Npts
        points[1, n] = x[n]
        points[2, n] = y[n]
        points[3, n] = z[n]
    end
    return vtk_grid(filename_noext, points, cells;
                    compress=compress, append=append)::DatasetFile
end

# 2D version
vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractVector{T}, y::AbstractVector{T},
        cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true) =
    vtk_grid(filename_noext, x, y, zero(x), cells, compress=compress, append=append)

# 1D version
vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        x::AbstractVector{T},
        cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true) =
    vtk_grid(filename_noext, x, zero(x), zero(x), cells, compress=compress, append=append)

# Variant with 4-D Array
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        points::AbstractArray{T,4}, cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)

    dim, Ni, Nj, Nk = size(points)

    return vtk_grid(filename_noext, reshape(points,(dim,Ni*Nj*Nk)), cells, compress=compress, append=append)
end
