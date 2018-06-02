function unstructured_grid(filename::AbstractString, points::AbstractArray,
                           cells::Vector{<:MeshCell};
                           compress=true, append::Bool=true)
    @assert size(points, 1) == 3
    Npts = prod(size(points)[2:end])
    Ncls = length(cells)

    xvtk = XMLDocument()
    vtk = DatasetFile(xvtk, add_extension(filename, ".vtu"), "UnstructuredGrid",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # UnstructuredGrid node
    xGrid = new_child(xroot, vtk.grid_type)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", vtk.Npts)
    set_attribute(xPiece, "NumberOfCells",  vtk.Ncls)

    # Points node
    xPoints = new_child(xPiece, "Points")

    # DataArray node
    data_to_xml(vtk, xPoints, points, "Points", 3)

    # Cells node (below the Piece node)
    xCells = new_child(xPiece, "Cells")

    # Create data arrays.
    offsets = Array{Int32}(undef, Ncls)
    types = Array{UInt8}(undef, Ncls)

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
    conn = Array{Int32}(undef, Nconn)
    ONE = one(Int32)
    n = 1
    for c in cells
        for i in c.connectivity
            # We transform to zero-based indexing, required by VTK.
            conn[n] = i - ONE
            n += 1
        end
    end

    # Add arrays to the XML file (DataArray nodes).
    data_to_xml(vtk, xCells, conn, "connectivity")
    data_to_xml(vtk, xCells, offsets, "offsets")
    data_to_xml(vtk, xCells, types, "types")

    vtk::DatasetFile
end

# Variant of vtk_grid with 2-D array "points".
#   size(points) = (dim, num_points), with dim ∈ {1, 2, 3}
function vtk_grid(filename::AbstractString, points::AbstractArray{T,2},
                  cells::Vector{<:MeshCell}; kwargs...) where T
    dim, Npts = size(points)
    if dim == 3
        return unstructured_grid(filename, points, cells; kwargs...)
    end
    # Reshape to 3D
    _points = zeros(T, 3, Npts)
    if dim == 1
        _points[1, :] = points
    elseif dim == 2
        _points[1:2, :] = points
    else
        msg = string("`points` array must be of size (dim, Npts), ",
                     "where dim = 1, 2 or 3 and `Npts` the number of points.\n",
                     "Actual size of input: $(size(points))")
        throw(ArgumentError(msg))
    end
    unstructured_grid(filename, _points, cells; kwargs...)
end

# Variant of vtk_grid with 1-D arrays x, y, z.
# Size of each array: (num_points)
function vtk_grid(filename::AbstractString, x::AbstractVector{T},
                  y::AbstractVector{T}, z::AbstractVector{T},
                  cells::Vector{<:MeshCell}; kwargs...) where T
    if !(length(x) == length(y) == length(z))
        throw(ArgumentError("Length of x, y and z arrays must be the same."))
    end
    Npts = length(x)
    points = Array{T}(undef, 3, Npts)
    for n = 1:Npts
        points[1, n] = x[n]
        points[2, n] = y[n]
        points[3, n] = z[n]
    end
    unstructured_grid(filename, points, cells; kwargs...)
end

# 2D version
vtk_grid(filename::AbstractString, x::AbstractVector{T},
         y::AbstractVector{T}, cells::Vector{<:MeshCell};
         kwargs...) where T =
    vtk_grid(filename, x, y, zero(x), cells; kwargs...)

# 1D version
vtk_grid(filename::AbstractString, x::AbstractVector{T},
         cells::Vector{<:MeshCell}; kwargs...) where T =
    vtk_grid(filename, x, zero(x), zero(x), cells; kwargs...)

# Variant with 4-D Array (for "pseudo-unstructured" datasets, i.e., those that
# actually have a 3D structure) -- maybe this variant should be removed...
function vtk_grid(filename::AbstractString, points::AbstractArray{T,4},
                  cells::Vector{<:MeshCell}; kwargs...) where T
    dim, Ni, Nj, Nk = size(points)
    points_r = reshape(points, (dim, Ni*Nj*Nk))
    unstructured_grid(filename, points_r, cells; kwargs...)
end
