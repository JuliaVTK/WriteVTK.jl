# TODO
# - merge with MeshCell and unstructured grids (it's very similar...)
# - add tests!
# - document!

module PolyData

abstract type CellType end

struct Verts <: CellType end
struct Lines <: CellType end
struct Strips <: CellType end
struct Polys <: CellType end

number_attr(::Type{Verts}) = "NumberOfVerts"
number_attr(::Type{Lines}) = "NumberOfLines"
number_attr(::Type{Strips}) = "NumberOfStrips"
number_attr(::Type{Polys}) = "NumberOfPolys"

xml_node(::Type{Verts}) = "Verts"
xml_node(::Type{Lines}) = "Lines"
xml_node(::Type{Strips}) = "Strips"
xml_node(::Type{Polys}) = "Polys"

end

import .PolyData

"""
    PolyCell{cell_type <: PolyData.CellType}

Single polygonal cell in a VTKPolyData dataset.

The `cell_type` parameter corresponds to one of the cell types supported by
VTKPolyData:

- `PolyData.Verts` for vertices,
- `PolyData.Lines` for lines,
- `PolyData.Strips` for triangular strips,
- `PolyData.Polys` for polygons.

---

    PolyCell(::Type{CellType}, connectivity)

Define a single polygonal cell.

As in [`MeshCell`](@ref), the `connectivity` argument contains the indices of
the points defining the cell.
"""
struct PolyCell{Cell <: PolyData.CellType, Indices <: AbstractVector{<:Integer}}
    connectivity :: Indices
    PolyCell(::Type{C}, conn) where {C} = new{C, typeof(conn)}(conn)
    PolyCell(c, conn) = PolyCell(typeof(c), conn)
end

cell_type(::Type{<:PolyCell{C}}) where {C} = C

# Add different types of PolyCell (lines, vertices, ...) recursively.
function add_poly_cells!(vtk, xml_piece, cells::AbstractArray{<:PolyCell}, etc...)
    ctype = cell_type(eltype(cells))
    Nc = length(cells)
    set_attribute(xml_piece, PolyData.number_attr(ctype), Nc)

    offsets = Array{Int32}(undef, Nc)
    Nconn = 0   # length of the connectivity array
    if Nc >= 1  # it IS possible to have no cells
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
    n = 1
    for c in cells, i in c.connectivity
        # We transform to zero-based indexing, required by VTK.
        conn[n] = i - 1
        n += 1
    end

    xnode = new_child(xml_piece, PolyData.xml_node(ctype))
    data_to_xml(vtk, xnode, conn, "connectivity")
    data_to_xml(vtk, xnode, offsets, "offsets")

    add_poly_cells!(vtk, xml_piece, etc...)
end

add_poly_cells!(vtk, xml) = vtk

function vtk_grid(dtype::VTKPolyData, filename::AbstractString,
                  points::AbstractArray,
                  cells::Vararg{AbstractArray{<:PolyCell}}; kwargs...)
    if isempty(cells)
        throw(ArgumentError(
            "constructing PolyData dataset with no cells is not allowed"))
    end

    @assert size(points, 1) == 3
    Npts = prod(size(points)[2:end])
    Ncls = sum(length, cells)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    xroot = vtk_xml_write_header(vtk)
    xGrid = new_child(xroot, vtk.grid_type)

    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "NumberOfPoints", Npts)

    xPoints = new_child(xPiece, "Points")
    data_to_xml(vtk, xPoints, points, "Points", 3)

    add_poly_cells!(vtk, xPiece, cells...)

    vtk
end

# TODO
# - allow different `points` specifications
# - merge some code with unstructured.jl
function vtk_grid(filename::AbstractString, points::AbstractArray{T,2} where T,
                  cells::Vararg{AbstractArray{<:PolyCell}}; kwargs...)
    dim, Npts = size(points)
    if dim != 3
        throw(ArgumentError(
            "for now, dimension of `points` for PolyData file must be (3, num_points)"))
    end
    vtk_grid(VTKPolyData(), filename, points, cells...; kwargs...)
end
