# Variant of vtk_grid with 2-D array "points".
# Size: (3, num_points)
# Note that reshaped arrays are also accepted (as long as they have the correct
# ordering).
function vtk_grid{T<:AbstractFloat}(
        filename_noext::AbstractString,
        points::Array{T}, cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)

    xvtk = XMLDocument()

    Npts = div(length(points), 3)
    Ncls = length(cells)
    if 3*Npts != length(points)
        error("Length of POINTS should be a multiple of 3.")
    end
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
    data_to_xml(vtk, xPoints, points, "Points", 3)

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
        types[n] = c.ctype
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
        x::Array{T}, y::Array{T}, z::Array{T}, cells::Vector{MeshCell};
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
