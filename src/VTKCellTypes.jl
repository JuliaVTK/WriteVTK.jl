# VTK cell definitions

# Definitions copied from the vtkCellType.h file of the VTK source code:
# https://raw.githubusercontent.com/Kitware/VTK/master/Common/DataModel/vtkCellType.h

__precompile__()

module VTKCellTypes

struct VTKCellType
    vtk_name::String
    vtk_id::UInt8
    nodes::Int
end


# Linear cells
const VTK_EMPTY_CELL       = VTKCellType("VTK_EMPTY_CELL",      UInt8(0),  0)
const VTK_VERTEX           = VTKCellType("VTK_VERTEX",          UInt8(1),  1)
const VTK_POLY_VERTEX      = VTKCellType("VTK_POLY_VERTEX",     UInt8(2), -1)
const VTK_LINE             = VTKCellType("VTK_LINE",            UInt8(3),  2)
const VTK_POLY_LINE        = VTKCellType("VTK_POLY_LINE",       UInt8(4), -1)
const VTK_TRIANGLE         = VTKCellType("VTK_TRIANGLE",        UInt8(5),  3)
const VTK_TRIANGLE_STRIP   = VTKCellType("VTK_TRIANGLE_STRIP",  UInt8(6), -1)
const VTK_POLYGON          = VTKCellType("VTK_POLYGON",         UInt8(7), -1)
const VTK_PIXEL            = VTKCellType("VTK_PIXEL",           UInt8(8),  4)
const VTK_QUAD             = VTKCellType("VTK_QUAD",            UInt8(9),  4)
const VTK_TETRA            = VTKCellType("VTK_TETRA",           UInt8(10), 4)
const VTK_VOXEL            = VTKCellType("VTK_VOXEL",           UInt8(11), 8)
const VTK_HEXAHEDRON       = VTKCellType("VTK_HEXAHEDRON",      UInt8(12), 8)
const VTK_WEDGE            = VTKCellType("VTK_WEDGE",           UInt8(13), 6)
const VTK_PYRAMID          = VTKCellType("VTK_PYRAMID",         UInt8(14), 5)
const VTK_PENTAGONAL_PRISM = VTKCellType("VTK_PENTAGONAL_PRISM",UInt8(15),10)
const VTK_HEXAGONAL_PRISM  = VTKCellType("VTK_HEXAGONAL_PRISM", UInt8(16),12)

# Quadratic, isoparametric cells
const VTK_QUADRATIC_EDGE                   = VTKCellType("VTK_QUADRATIC_EDGE",                  UInt8(21), 3)
const VTK_QUADRATIC_TRIANGLE               = VTKCellType("VTK_QUADRATIC_TRIANGLE",              UInt8(22), 6)
const VTK_QUADRATIC_QUAD                   = VTKCellType("VTK_QUADRATIC_QUAD",                  UInt8(23), 8)
const VTK_QUADRATIC_POLYGON                = VTKCellType("VTK_QUADRATIC_POLYGON",               UInt8(36),-1)
const VTK_QUADRATIC_TETRA                  = VTKCellType("VTK_QUADRATIC_TETRA",                 UInt8(24),10)
const VTK_QUADRATIC_HEXAHEDRON             = VTKCellType("VTK_QUADRATIC_HEXAHEDRON",            UInt8(25),20)
const VTK_QUADRATIC_WEDGE                  = VTKCellType("VTK_QUADRATIC_WEDGE",                 UInt8(26),15)
const VTK_QUADRATIC_PYRAMID                = VTKCellType("VTK_QUADRATIC_PYRAMID",               UInt8(27),13)
const VTK_BIQUADRATIC_QUAD                 = VTKCellType("VTK_BIQUADRATIC_QUAD",                UInt8(28), 9)
const VTK_TRIQUADRATIC_HEXAHEDRON          = VTKCellType("VTK_TRIQUADRATIC_HEXAHEDRON",         UInt8(29),27)
const VTK_QUADRATIC_LINEAR_QUAD            = VTKCellType("VTK_QUADRATIC_LINEAR_QUAD",           UInt8(30), 6)
const VTK_QUADRATIC_LINEAR_WEDGE           = VTKCellType("VTK_QUADRATIC_LINEAR_WEDGE",          UInt8(31),12)
const VTK_BIQUADRATIC_QUADRATIC_WEDGE      = VTKCellType("VTK_BIQUADRATIC_QUADRATIC_WEDGE",     UInt8(32),18)
const VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON = VTKCellType("VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON",UInt8(33),24)
const VTK_BIQUADRATIC_TRIANGLE             = VTKCellType("VTK_BIQUADRATIC_TRIANGLE",            UInt8(34), 7)

# Cubic, isoparametric cell
const VTK_CUBIC_LINE                       = VTKCellType("VTK_CUBIC_LINE",UInt8(35),4)

# Special class of cells formed by convex group of points
const VTK_CONVEX_POINT_SET = VTKCellType("VTK_CONVEX_POINT_SET",UInt8(41),-1)

# Polyhedron cell (consisting of polygonal faces)
const VTK_POLYHEDRON = VTKCellType("VTK_POLYHEDRON",UInt8(42),-1)

# Higher order cells in parametric form
const VTK_PARAMETRIC_CURVE        = VTKCellType("VTK_PARAMETRIC_CURVE",       UInt8(51),-1)
const VTK_PARAMETRIC_SURFACE      = VTKCellType("VTK_PARAMETRIC_SURFACE",     UInt8(52),-1)
const VTK_PARAMETRIC_TRI_SURFACE  = VTKCellType("VTK_PARAMETRIC_TRI_SURFACE", UInt8(53),-1)
const VTK_PARAMETRIC_QUAD_SURFACE = VTKCellType("VTK_PARAMETRIC_QUAD_SURFACE",UInt8(54),-1)
const VTK_PARAMETRIC_TETRA_REGION = VTKCellType("VTK_PARAMETRIC_TETRA_REGION",UInt8(55),-1)
const VTK_PARAMETRIC_HEX_REGION   = VTKCellType("VTK_PARAMETRIC_HEX_REGION",  UInt8(56),-1)

# Higher order cells
const VTK_HIGHER_ORDER_EDGE        = VTKCellType("VTK_HIGHER_ORDER_EDGE",       UInt8(60),-1)
const VTK_HIGHER_ORDER_TRIANGLE    = VTKCellType("VTK_HIGHER_ORDER_TRIANGLE",   UInt8(61),-1)
const VTK_HIGHER_ORDER_QUAD        = VTKCellType("VTK_HIGHER_ORDER_QUAD",       UInt8(62),-1)
const VTK_HIGHER_ORDER_POLYGON     = VTKCellType("VTK_HIGHER_ORDER_POLYGON",    UInt8(63),-1)
const VTK_HIGHER_ORDER_TETRAHEDRON = VTKCellType("VTK_HIGHER_ORDER_TETRAHEDRON",UInt8(64),-1)
const VTK_HIGHER_ORDER_WEDGE       = VTKCellType("VTK_HIGHER_ORDER_WEDGE",      UInt8(65),-1)
const VTK_HIGHER_ORDER_PYRAMID     = VTKCellType("VTK_HIGHER_ORDER_PYRAMID",    UInt8(66),-1)
const VTK_HIGHER_ORDER_HEXAHEDRON  = VTKCellType("VTK_HIGHER_ORDER_HEXAHEDRON", UInt8(67),-1)

end # module
