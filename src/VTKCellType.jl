# VTK cell definitions

# Definitions copied from the vtkCellType.h file of the VTK source code:
# https://raw.githubusercontent.com/Kitware/VTK/master/Common/DataModel/vtkCellType.h

__precompile__()

module VTKCellType

# Linear cells
const VTK_EMPTY_CELL       = UInt8(0)
const VTK_VERTEX           = UInt8(1)
const VTK_POLY_VERTEX      = UInt8(2)
const VTK_LINE             = UInt8(3)
const VTK_POLY_LINE        = UInt8(4)
const VTK_TRIANGLE         = UInt8(5)
const VTK_TRIANGLE_STRIP   = UInt8(6)
const VTK_POLYGON          = UInt8(7)
const VTK_PIXEL            = UInt8(8)
const VTK_QUAD             = UInt8(9)
const VTK_TETRA            = UInt8(10)
const VTK_VOXEL            = UInt8(11)
const VTK_HEXAHEDRON       = UInt8(12)
const VTK_WEDGE            = UInt8(13)
const VTK_PYRAMID          = UInt8(14)
const VTK_PENTAGONAL_PRISM = UInt8(15)
const VTK_HEXAGONAL_PRISM  = UInt8(16)

# Quadratic, isoparametric cells
const VTK_QUADRATIC_EDGE                   = UInt8(21)
const VTK_QUADRATIC_TRIANGLE               = UInt8(22)
const VTK_QUADRATIC_QUAD                   = UInt8(23)
const VTK_QUADRATIC_POLYGON                = UInt8(36)
const VTK_QUADRATIC_TETRA                  = UInt8(24)
const VTK_QUADRATIC_HEXAHEDRON             = UInt8(25)
const VTK_QUADRATIC_WEDGE                  = UInt8(26)
const VTK_QUADRATIC_PYRAMID                = UInt8(27)
const VTK_BIQUADRATIC_QUAD                 = UInt8(28)
const VTK_TRIQUADRATIC_HEXAHEDRON          = UInt8(29)
const VTK_QUADRATIC_LINEAR_QUAD            = UInt8(30)
const VTK_QUADRATIC_LINEAR_WEDGE           = UInt8(31)
const VTK_BIQUADRATIC_QUADRATIC_WEDGE      = UInt8(32)
const VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON = UInt8(33)
const VTK_BIQUADRATIC_TRIANGLE             = UInt8(34)

# Cubic, isoparametric cell
const VTK_CUBIC_LINE                       = UInt8(35)

# Special class of cells formed by convex group of points
const VTK_CONVEX_POINT_SET = UInt8(41)

# Polyhedron cell (consisting of polygonal faces)
const VTK_POLYHEDRON = UInt8(42)

# Higher order cells in parametric form
const VTK_PARAMETRIC_CURVE        = UInt8(51)
const VTK_PARAMETRIC_SURFACE      = UInt8(52)
const VTK_PARAMETRIC_TRI_SURFACE  = UInt8(53)
const VTK_PARAMETRIC_QUAD_SURFACE = UInt8(54)
const VTK_PARAMETRIC_TETRA_REGION = UInt8(55)
const VTK_PARAMETRIC_HEX_REGION   = UInt8(56)

# Higher order cells
const VTK_HIGHER_ORDER_EDGE        = UInt8(60)
const VTK_HIGHER_ORDER_TRIANGLE    = UInt8(61)
const VTK_HIGHER_ORDER_QUAD        = UInt8(62)
const VTK_HIGHER_ORDER_POLYGON     = UInt8(63)
const VTK_HIGHER_ORDER_TETRAHEDRON = UInt8(64)
const VTK_HIGHER_ORDER_WEDGE       = UInt8(65)
const VTK_HIGHER_ORDER_PYRAMID     = UInt8(66)
const VTK_HIGHER_ORDER_HEXAHEDRON  = UInt8(67)

end
