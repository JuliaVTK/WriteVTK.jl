module WriteVTK

# TODO
# - Add better support for 2D datasets (slices).
# - Reduce duplicate code: data_to_xml() variants...
# - Allow AbstractArray types.
#   NOTE: using SubArrays/ArrayViews can be significantly slower!!
# - Add tests for non-default cases (append=false, compress=false in vtk_grid).
# - Add MeshCell constructors for common cell types (triangles, quads,
#   tetrahedrons, hexahedrons, ...).
#   That stuff should probably be included in a separate file.
# - Point definition between structured and unstructured grids is inconsistent!!
#   (There's no reason why their definitions should be different...)

# All the code is based on the VTK file specification [1], plus some
# undocumented stuff found around the internet...
# [1] http://www.vtk.org/VTK/img/file-formats.pdf

export VTKCellType
export MeshCell
export vtk_grid, vtk_save, vtk_point_data, vtk_cell_data
export vtk_multiblock

using LightXML
import Zlib

using Compat

# More compatibility with Julia 0.3.
if VERSION < v"0.4-"
    const base64encode = base64::Function
end

# Cell type definitions as in vtkCellType.h
include("VTKCellType.jl")

# ====================================================================== #
## Constants ##
const COMPRESSION_LEVEL = 6

# ====================================================================== #
## Types ##
abstract VTKFile
abstract DatasetFile <: VTKFile

# Cells in unstructured meshes.
immutable MeshCell
    ctype::UInt8                 # cell type identifier (see vtkCellType.jl)
    connectivity::Vector{Int32}  # indices of points (one-based, like in Julia!!)
end

include("gridtypes/multiblock.jl")

include("gridtypes/structured.jl")
include("gridtypes/unstructured.jl")
include("gridtypes/rectilinear.jl")

include("gridtypes/common.jl")

# TODO move this documentation!!
#==========================================================================#
# Creates a new grid file with coordinates x, y, z.
#
# The saved file has the name given by filename_noext, and its extension
# depends on the type of grid, which is determined by the shape of the
# arrays x, y, z.
#
# Accepted grid types:
#   * Rectilinear grid      x, y, z are 1D arrays with possibly different
#                           lengths.
#
#   * Structured grid       x, y, z are 3D arrays with the same dimensions.
#                           TODO: also allow a single "4D" array, just like
#                           for unstructured grids, which would give a
#                           better performance.
#
#   * Unstructured grid     x is an array with all the points, with
#                           dimensions [3, num_points].
#                           cells is a MeshCell array with all the cells.
#
#                           NOTE: for convenience, there's also a separate
#                           vtk_grid function specifically made for
#                           unstructured grids.
#
# Optional parameters:
# * If compress is true, written data is first compressed using Zlib.
#   Set to false if you don't care about file size, or if speed is really
#   important.
#
# * If append is true, data is appended at the end of the XML file as raw
#   binary data.
#   Otherwise, data is written inline, base-64 encoded. This is usually
#   slower than writing raw binary data, and also results in larger files.
#   Try disabling this if there are issues (for example with portability?),
#   or if it's really important to follow the XML specifications.
#
#   Note that all combinations of compress and append are supported.
#
#==========================================================================#

end     # module WriteVTK
