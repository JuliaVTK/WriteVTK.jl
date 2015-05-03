# VTK cell definitions

# Definitions copied from the vtkCellType.h file of the VTK source code:
# https://github.com/Kitware/VTK/blob/master/Common/DataModel/vtkCellType.h

# TODO Maybe these should be declared as UInt8??

# Linear cells
const VTK_EMPTY_CELL       = 0
const VTK_VERTEX           = 1
const VTK_POLY_VERTEX      = 2
const VTK_LINE             = 3
const VTK_POLY_LINE        = 4
const VTK_TRIANGLE         = 5
const VTK_TRIANGLE_STRIP   = 6
const VTK_POLYGON          = 7
const VTK_PIXEL            = 8
const VTK_QUAD             = 9
const VTK_TETRA            = 10
const VTK_VOXEL            = 11
const VTK_HEXAHEDRON       = 12
const VTK_WEDGE            = 13
const VTK_PYRAMID          = 14
const VTK_PENTAGONAL_PRISM = 15
const VTK_HEXAGONAL_PRISM  = 16

# Quadratic, isoparametric cells
const VTK_QUADRATIC_EDGE                   = 21
const VTK_QUADRATIC_TRIANGLE               = 22
const VTK_QUADRATIC_QUAD                   = 23
const VTK_QUADRATIC_POLYGON                = 36
const VTK_QUADRATIC_TETRA                  = 24
const VTK_QUADRATIC_HEXAHEDRON             = 25
const VTK_QUADRATIC_WEDGE                  = 26
const VTK_QUADRATIC_PYRAMID                = 27
const VTK_BIQUADRATIC_QUAD                 = 28
const VTK_TRIQUADRATIC_HEXAHEDRON          = 29
const VTK_QUADRATIC_LINEAR_QUAD            = 30
const VTK_QUADRATIC_LINEAR_WEDGE           = 31
const VTK_BIQUADRATIC_QUADRATIC_WEDGE      = 32
const VTK_BIQUADRATIC_QUADRATIC_HEXAHEDRON = 33
const VTK_BIQUADRATIC_TRIANGLE             = 34

# Cubic, isoparametric cell
const VTK_CUBIC_LINE                       = 35

# Special class of cells formed by convex group of points
const VTK_CONVEX_POINT_SET = 41

# Polyhedron cell (consisting of polygonal faces)
const VTK_POLYHEDRON = 42

# Higher order cells in parametric form
const VTK_PARAMETRIC_CURVE        = 51
const VTK_PARAMETRIC_SURFACE      = 52
const VTK_PARAMETRIC_TRI_SURFACE  = 53
const VTK_PARAMETRIC_QUAD_SURFACE = 54
const VTK_PARAMETRIC_TETRA_REGION = 55
const VTK_PARAMETRIC_HEX_REGION   = 56

# Higher order cells
const VTK_HIGHER_ORDER_EDGE        = 60
const VTK_HIGHER_ORDER_TRIANGLE    = 61
const VTK_HIGHER_ORDER_QUAD        = 62
const VTK_HIGHER_ORDER_POLYGON     = 63
const VTK_HIGHER_ORDER_TETRAHEDRON = 64
const VTK_HIGHER_ORDER_WEDGE       = 65
const VTK_HIGHER_ORDER_PYRAMID     = 66
const VTK_HIGHER_ORDER_HEXAHEDRON  = 67

