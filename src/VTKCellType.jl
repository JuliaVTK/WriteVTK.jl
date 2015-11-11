# VTK cell definitions

# Definitions copied from the vtkCellType.h file of the VTK source code:
# https://github.com/Kitware/VTK/blob/master/Common/DataModel/vtkCellType.h

VERSION >= v"0.4.0-dev+6521" && __precompile__()

module VTKCellType

toUInt8(x) = convert(UInt8, x)

# Linear cells
const VTK_EMPTY_CELL       = toUInt8(0)
const VTK_VERTEX           = toUInt8(1)
const VTK_POLY_VERTEX      = toUInt8(2)
const VTK_LINE             = toUInt8(3)
const VTK_POLY_LINE        = toUInt8(4)
const VTK_TRIANGLE         = toUInt8(5)
const VTK_TRIANGLE_STRIP   = toUInt8(6)
const VTK_POLYGON          = toUInt8(7)
const VTK_PIXEL            = toUInt8(8)
const VTK_QUAD             = toUInt8(9)
const VTK_TETRA            = toUInt8(10)
const VTK_VOXEL            = toUInt8(11)
const VTK_HEXAHEDRON       = toUInt8(12)
const VTK_WEDGE            = toUInt8(13)
const VTK_PYRAMID          = toUInt8(14)
const VTK_PENTAGONAL_PRISM = toUInt8(15)
const VTK_HEXAGONAL_PRISM  = toUInt8(16)

# Quadratic, isoparametric cells
const VTK_QUADRATIC_EDGE                   = toUInt8(21)
const VTK_QUADRATIC_TRIANGLE               = toUInt8(22)
const VTK_QUADRATIC_QUAD                   = toUInt8(23)
const VTK_QUADRATIC_POLYGON                = toUInt8(36)
const VTK_QUADRATIC_TETRA                  = toUInt8(24)
const VTK_QUADRATIC_HEXAHEDRON             = toUInt8(25)
const VTK_QUADRATIC_WEDGE                  = toUInt8(26)
const VTK_QUADRATIC_PYRAMID                = toUInt8(27)
const VTK_BIQUADRATIC_QUAD                 = toUInt8(28)
const VTK_TRIQUADRATIC_HEXAHEDRON          = toUInt8(29)
const VTK_QUADRATIC_LINEAR_QUAD            = toUInt8(30)
const VTK_QUADRATIC_LINEAR_WEDGE           = toUInt8(31)
const VTK_BIQUADRATIC_QUADRATIC_WEDGE      = toUInt8(32)
const VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON = toUInt8(33)
const VTK_BIQUADRATIC_TRIANGLE             = toUInt8(34)

# Cubic, isoparametric cell
const VTK_CUBIC_LINE                       = toUInt8(35)

# Special class of cells formed by convex group of points
const VTK_CONVEX_POINT_SET = toUInt8(41)

# Polyhedron cell (consisting of polygonal faces)
const VTK_POLYHEDRON = toUInt8(42)

# Higher order cells in parametric form
const VTK_PARAMETRIC_CURVE        = toUInt8(51)
const VTK_PARAMETRIC_SURFACE      = toUInt8(52)
const VTK_PARAMETRIC_TRI_SURFACE  = toUInt8(53)
const VTK_PARAMETRIC_QUAD_SURFACE = toUInt8(54)
const VTK_PARAMETRIC_TETRA_REGION = toUInt8(55)
const VTK_PARAMETRIC_HEX_REGION   = toUInt8(56)

# Higher order cells
const VTK_HIGHER_ORDER_EDGE        = toUInt8(60)
const VTK_HIGHER_ORDER_TRIANGLE    = toUInt8(61)
const VTK_HIGHER_ORDER_QUAD        = toUInt8(62)
const VTK_HIGHER_ORDER_POLYGON     = toUInt8(63)
const VTK_HIGHER_ORDER_TETRAHEDRON = toUInt8(64)
const VTK_HIGHER_ORDER_WEDGE       = toUInt8(65)
const VTK_HIGHER_ORDER_PYRAMID     = toUInt8(66)
const VTK_HIGHER_ORDER_HEXAHEDRON  = toUInt8(67)

end
