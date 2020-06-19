# TODO
# - add other "poly" types: points, vertices, triangle strips
# - combine with MeshCell and unstructured grids (it's very similar...)
# - add tests!
# - document!

struct VTKPolyLine{Indices <: AbstractVector{<:Integer}}
    connectivity :: Indices
end

function vtk_grid(dtype::VTKPolyData, filename::AbstractString,
                  points::AbstractArray, lines::AbstractArray{<:VTKPolyLine};
                  kwargs...)
    @assert size(points, 1) == 3
    Npts = prod(size(points)[2:end])
    Ncls = length(lines)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    xroot = vtk_xml_write_header(vtk)
    xGrid = new_child(xroot, vtk.grid_type)

    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", Npts)
    set_attribute(xPiece, "NumberOfLines",  length(lines))

    xPoints = new_child(xPiece, "Points")
    data_to_xml(vtk, xPoints, points, "Points", 3)

    xLines = new_child(xPiece, "Lines")

    # Create data arrays.
    # (Very similar to unstructured grids...)
    let cells = lines, xCells = xLines
        Nc = length(cells)
        offsets = Array{Int32}(undef, Nc)
        Nconn = 0     # length of the connectivity array
        if Ncls >= 1  # it IS possible to have no cells
            offsets[1] = length(cells[1].connectivity)
        end
        for (n, c) in enumerate(cells)
            Npts_cell = length(c.connectivity)
            Nconn += Npts_cell
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
        data_to_xml(vtk, xCells, conn, "connectivity")
        data_to_xml(vtk, xCells, offsets, "offsets")
    end

    vtk
end

# TODO
# - allow different `points` specifications
# - merge some code with unstructured.jl
function vtk_grid(filename::AbstractString, points::AbstractArray{T,2} where T,
                  lines::AbstractArray{<:VTKPolyLine}; kwargs...)
    dim, Npts = size(points)
    if dim != 3
        throw(ArgumentError(
            "for now, dimension of `points` for PolyData file must be (3, num_points)"))
    end
    vtk_grid(VTKPolyData(), filename, points, lines; kwargs...)
end
