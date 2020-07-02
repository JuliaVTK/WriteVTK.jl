"""
    PolyData

Defines cell types for polygonal datasets.

The following singleton types are defined:

- `PolyData.Verts` for vertices,
- `PolyData.Lines` for lines,
- `PolyData.Strips` for triangular strips,
- `PolyData.Polys` for polygons.

"""
module PolyData

import ..VTKCellTypes: nodes

abstract type CellType end

struct Verts <: CellType end
struct Lines <: CellType end
struct Strips <: CellType end
struct Polys <: CellType end

# All of these cell types can take any number of grid points.
# (This is for compatibility with VTKCellTypes for unstructured datasets.)
nodes(::CellType) = -1

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

const PolyCell{T} = MeshCell{T} where {T <: PolyData.CellType}

Base.eltype(::Type{T}) where {T <: PolyCell} = cell_type(T)
cell_type(::Type{<:PolyCell{T}}) where {T} = T
grid_type(::Type{<:PolyCell}) = VTKPolyData()

# Add different types of PolyCell (lines, vertices, ...) recursively.
function add_poly_cells!(vtk, xml_piece, cells::AbstractArray{<:PolyCell},
                         etc...)
    ctype = eltype(eltype(cells))
    add_cells!(vtk, xml_piece, PolyData.number_attr(ctype),
               PolyData.xml_node(ctype), cells, with_types=Val(false))
    add_poly_cells!(vtk, xml_piece, etc...)
end

add_poly_cells!(vtk, xml) = vtk

function vtk_grid(dtype::VTKPolyData, filename::AbstractString,
                  points::UnstructuredCoords,
                  cells::Vararg{AbstractArray{<:PolyCell}}; kwargs...)
    if isempty(cells)
        throw(ArgumentError(
            "constructing PolyData dataset with no cells is not allowed"))
    end

    Npts = num_points(dtype, points)
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
