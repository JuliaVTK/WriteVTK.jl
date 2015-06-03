module WriteVTK

# TODO
# - Merge all the different subtypes of DatasetFile??
#   (They're all the same...)
# - Support PVD files for ParaView?
# - Add better support for 2D datasets (slices).
# - Allow AbstractArray types.
#   NOTE: using SubArrays/ArrayViews can be significantly slower!!

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

## Constants ##
const COMPRESSION_LEVEL = 6

## Types ##
abstract VTKFile
abstract DatasetFile <: VTKFile

# Cells in unstructured meshes.
immutable MeshCell
    ctype::UInt8                 # cell type identifier (see VTKCellType.jl)
    connectivity::Vector{Int32}  # indices of points (one-based, like in Julia!!)
end

# Multiblock-specific functions and types.
include("gridtypes/multiblock.jl")

# Grid-specific functions and types.
include("gridtypes/structured.jl")
include("gridtypes/unstructured.jl")
include("gridtypes/rectilinear.jl")

# Common functions.
include("gridtypes/common.jl")

end     # module WriteVTK
