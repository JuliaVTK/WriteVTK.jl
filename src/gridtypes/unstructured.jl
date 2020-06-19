function add_cells!(vtk, xml_piece, number_attr, xml_name, cells;
                    with_types=true)
    Cell = eltype(cells)
    Ncls = length(cells)

    # Create data arrays.
    offsets = Array{Int32}(undef, Ncls)

    # Write `types` array? This must be true for unstructured grids,
    # and false for polydata.
    if with_types
        types = Array{UInt8}(undef, Ncls)
    end

    Nconn = 0     # length of the connectivity array
    if Ncls >= 1  # it IS possible to have no cells
        offsets[1] = length(cells[1].connectivity)
    end

    for (n, c) in enumerate(cells)
        Npts_cell = length(c.connectivity)
        Nconn += Npts_cell
        if with_types
            types[n] = cell_type(c).vtk_id
        end
        if n >= 2
            offsets[n] = offsets[n-1] + Npts_cell
        end
    end

    # Create connectivity array.
    conn = Array{Int32}(undef, Nconn)
    ONE = one(Int32)
    n = 1
    for c in cells, i in c.connectivity
        # We transform to zero-based indexing, required by VTK.
        conn[n] = i - ONE
        n += 1
    end

    # Add arrays to the XML file (DataArray nodes).
    set_attribute(xml_piece, number_attr, Ncls)

    xnode = new_child(xml_piece, xml_name)
    data_to_xml(vtk, xnode, conn, "connectivity")
    data_to_xml(vtk, xnode, offsets, "offsets")
    if with_types
        data_to_xml(vtk, xnode, types, "types")
    end

    vtk
end

function vtk_grid(dtype::VTKUnstructuredGrid, filename::AbstractString,
                  points::AbstractArray, cells::Vector{<:MeshCell};
                  kwargs...)
    @assert size(points, 1) == 3
    Npts = prod(size(points)[2:end])
    Ncls = length(cells)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    xroot = vtk_xml_write_header(vtk)
    xGrid = new_child(xroot, vtk.grid_type)

    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", vtk.Npts)

    xPoints = new_child(xPiece, "Points")
    data_to_xml(vtk, xPoints, points, "Points", 3)

    add_cells!(vtk, xPiece, "NumberOfCells", "Cells", cells)

    vtk
end

# Variant of vtk_grid with 2-D array "points".
#   size(points) = (dim, num_points), with dim ∈ {1, 2, 3}
function vtk_grid(filename::AbstractString, points::AbstractArray{T,2},
                  cells::Vector{<:MeshCell}; kwargs...) where T
    dim, Npts = size(points)
    if dim == 3
        return vtk_grid(VTKUnstructuredGrid(), filename, points, cells; kwargs...)
    end
    # Reshape to 3D
    _points = zeros(T, 3, Npts)
    Base.require_one_based_indexing(points)
    if dim ∉ (1, 2)
        msg = string("`points` array must be of size (dim, Npts), ",
                     "where dim = 1, 2 or 3 and `Npts` the number of points.\n",
                     "Actual size of input: $(size(points))")
        throw(ArgumentError(msg))
    end
    for I in CartesianIndices(points)
        _points[I] = points[I]
    end
    vtk_grid(VTKUnstructuredGrid(), filename, _points, cells; kwargs...)
end

# Variant of vtk_grid with 1-D arrays x, y, z.
# Size of each array: (num_points)
function vtk_grid(filename::AbstractString, x::AbstractVector{T},
                  y::AbstractVector{T}, z::AbstractVector{T},
                  cells::Vector{<:MeshCell}; kwargs...) where T
    if !(length(x) == length(y) == length(z))
        throw(ArgumentError("length of x, y and z arrays must be the same."))
    end
    Npts = length(x)
    points = Array{T}(undef, 3, Npts)
    for n = 1:Npts
        points[1, n] = x[n]
        points[2, n] = y[n]
        points[3, n] = z[n]
    end
    vtk_grid(VTKUnstructuredGrid(), filename, points, cells; kwargs...)
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
    vtk_grid(VTKUnstructuredGrid(), filename, points_r, cells; kwargs...)
end
