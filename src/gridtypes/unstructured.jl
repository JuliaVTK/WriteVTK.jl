# Included in WriteVTK.jl.

immutable UnstructuredFile <: DatasetFile
    xdoc::XMLDocument
    path::UTF8String
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    Ncls::Int           # Number of cells.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (or written inline, base64-encoded?)
    buf::IOBuffer       # Buffer with appended data.

    # Override default constructor.
    function UnstructuredFile(xdoc, path, Npts, Ncls, compressed, appended)
        gridType_str = "UnstructuredGrid"
        if appended
            buf = IOBuffer()
        else
            # In this case we don't need a buffer, so just use a closed one.
            buf = IOBuffer(0)
            close(buf)
        end
        return new(xdoc, path, gridType_str, Npts, Ncls, compressed,
                   appended, buf)
    end
end


function vtk_grid{T<:FloatingPoint}(
        filename_noext::AbstractString,
        points::Array{T}, cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)
    xvtk = XMLDocument()

    Npts = div(length(points), 3)
    Ncells = length(cells)
    if 3*Npts != length(points)
        error("Length of POINTS should be a multiple of 3.")
    end
    vtk = UnstructuredFile(xvtk, filename_noext*".vtu", Npts, Ncells,
                           compress, append)

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
    data_to_xml(vtk, xPoints, points, 3, "Points")

    # Cells node (below the Piece node)
    xCells = new_child(xPiece, "Cells")

    # Create data arrays.
    offsets = Array(Int32, Ncells)
    types = Array(UInt8, Ncells)

    Nconn = 0   # length of the connectivity array
    offsets[1] = length(cells[1].connectivity)

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
    data_to_xml(vtk, xCells, conn,    1, "connectivity")
    data_to_xml(vtk, xCells, offsets, 1, "offsets"     )
    data_to_xml(vtk, xCells, types,   1, "types"       )

    return vtk::UnstructuredFile
end


# Multiblock variant of vtk_grid.
function vtk_grid{T<:FloatingPoint}(
        vtm::MultiblockFile,
        points::Array{T}, cells::Vector{MeshCell};
        compress::Bool=true, append::Bool=true)
    path_base = splitext(vtm.path)[1]
    vtkFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))
    vtk = vtk_grid(vtkFilename_noext, points, cells;
                   compress=compress, append=append)
    multiblock_add_block(vtm, vtk)
    return vtk::DatasetFile
end

