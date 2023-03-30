using VTKBase:
    PolyData,
    PolyCell

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
