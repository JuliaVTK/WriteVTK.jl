VERSION >= v"0.4.0-dev+6521" && __precompile__()

module WriteVTK

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
const IS_LITTLE_ENDIAN = (ENDIAN_BOM == 0x04030201)  # see the documentation for ENDIAN_BOM

## Types ##
abstract VTKFile

immutable DatasetFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    Ncls::Int           # Number of cells.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (or written inline, base64-encoded?)
    buf::IOBuffer       # Buffer with appended data.
    function DatasetFile(xdoc, path, gridType_str, Npts, Ncls,
                         compressed, appended)
        if appended
            buf = IOBuffer()
        else
            # In this case we don't need a buffer, so just define a closed one.
            buf = IOBuffer(0)
            close(buf)
        end
        return new(xdoc, path, gridType_str, Npts, Ncls,
                   compressed, appended, buf)
    end
end

immutable MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    blocks::Vector{VTKFile}

    # Override default constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

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
