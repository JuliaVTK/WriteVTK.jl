"""
    VTKCellTypes

Module defining cell types for unstructured datasets.

Definitions are adapted from the [`VTK source
code`](https://raw.githubusercontent.com/Kitware/VTK/master/Common/DataModel/vtkCellType.h).
"""
module VTKCellTypes

export VTKCellType, nodes

struct VTKCellType
    vtk_name::String
    vtk_id::UInt8
    nodes::Int
end

"""
    nodes(c::VTKCellTypes)

Returns the number of nodes (or grid points) required by the cell type.

For instance, this returns 3 for `VTK_TRIANGLE`.

For cell types that can take any number of nodes, such as `VTK_POLY_LINE`,
this returns -1.
"""
nodes(c::VTKCellType) = c.nodes

const INVALID_CELL_TYPE = VTKCellType("INVALID", typemax(UInt8), -1)

# Array of known cell types
const VTK_CELL_TYPES = fill(INVALID_CELL_TYPE, typemax(UInt8))

# Construction of VTKCellType objects from the integer vtk id
function VTKCellType(vtkid::Integer)
    n = vtkid + 1  # ids start at zero
    cell = VTK_CELL_TYPES[n]
    if cell === INVALID_CELL_TYPE
        throw(ArgumentError("unknown vtkid = $vtkid"))
    end
    cell
end

# Define a VTK cell type
macro add(ctype, id, nodes=-1)
    name = string(ctype)
    quote
        const $(esc(ctype)) = VTKCellType($name, $id, $nodes)
        VTK_CELL_TYPES[$id + 1] = $(esc(ctype))
    end
end

# Linear cells
@add VTK_EMPTY_CELL 0 0
@add VTK_VERTEX 1  1
@add VTK_POLY_VERTEX 2 -1
@add VTK_LINE 3  2
@add VTK_POLY_LINE 4 -1
@add VTK_TRIANGLE 5  3
@add VTK_TRIANGLE_STRIP 6 -1
@add VTK_POLYGON 7 -1
@add VTK_PIXEL 8  4
@add VTK_QUAD 9  4
@add VTK_TETRA 10 4
@add VTK_VOXEL 11 8
@add VTK_HEXAHEDRON 12 8
@add VTK_WEDGE 13 6
@add VTK_PYRAMID 14 5
@add VTK_PENTAGONAL_PRISM 15 10
@add VTK_HEXAGONAL_PRISM 16 12

# Quadratic, isoparametric cells
@add VTK_QUADRATIC_EDGE 21 3
@add VTK_QUADRATIC_TRIANGLE 22 6
@add VTK_QUADRATIC_QUAD 23 8
@add VTK_QUADRATIC_POLYGON 36 -1
@add VTK_QUADRATIC_TETRA 24 10
@add VTK_QUADRATIC_HEXAHEDRON 25 20
@add VTK_QUADRATIC_WEDGE 26 15
@add VTK_QUADRATIC_PYRAMID 27 13
@add VTK_BIQUADRATIC_QUAD 28 9
@add VTK_TRIQUADRATIC_HEXAHEDRON 29 27
@add VTK_QUADRATIC_LINEAR_QUAD 30 6
@add VTK_QUADRATIC_LINEAR_WEDGE 31 12
@add VTK_BIQUADRATIC_QUADRATIC_WEDGE 32 18
@add VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON 33 24
@add VTK_BIQUADRATIC_TRIANGLE 34 7

# Cubic, isoparametric cell
@add VTK_CUBIC_LINE 35 4

# Special class of cells formed by convex group of points
@add VTK_CONVEX_POINT_SET 41

# Polyhedron cell (consisting of polygonal faces)
# NOTE: in WriteVTK.jl, use the VTKPolyhedron type instead of a MeshCell to
# describe this kind of cells.
@add VTK_POLYHEDRON 42

# Higher order cells in parametric form
@add VTK_PARAMETRIC_CURVE 51
@add VTK_PARAMETRIC_SURFACE 52
@add VTK_PARAMETRIC_TRI_SURFACE 53
@add VTK_PARAMETRIC_QUAD_SURFACE 54
@add VTK_PARAMETRIC_TETRA_REGION 55
@add VTK_PARAMETRIC_HEX_REGION 56

# Higher order cells
@add VTK_HIGHER_ORDER_EDGE 60
@add VTK_HIGHER_ORDER_TRIANGLE 61
@add VTK_HIGHER_ORDER_QUAD 62
@add VTK_HIGHER_ORDER_POLYGON 63
@add VTK_HIGHER_ORDER_TETRAHEDRON 64
@add VTK_HIGHER_ORDER_WEDGE 65
@add VTK_HIGHER_ORDER_PYRAMID 66
@add VTK_HIGHER_ORDER_HEXAHEDRON 67

# Arbitrary order Lagrange elements (formulated separated from generic higher order cells)
@add VTK_LAGRANGE_CURVE 68
@add VTK_LAGRANGE_TRIANGLE 69
@add VTK_LAGRANGE_QUADRILATERAL 70
@add VTK_LAGRANGE_TETRAHEDRON 71
@add VTK_LAGRANGE_HEXAHEDRON 72
@add VTK_LAGRANGE_WEDGE 73
@add VTK_LAGRANGE_PYRAMID 74

# Arbitrary order Bezier elements (formulated separated from generic higher order cells)
@add VTK_BEZIER_CURVE 75
@add VTK_BEZIER_TRIANGLE 76
@add VTK_BEZIER_QUADRILATERAL 77
@add VTK_BEZIER_TETRAHEDRON 78
@add VTK_BEZIER_HEXAHEDRON 79
@add VTK_BEZIER_WEDGE 80
@add VTK_BEZIER_PYRAMID 81

end # module
