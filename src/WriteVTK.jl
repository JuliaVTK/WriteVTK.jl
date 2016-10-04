__precompile__()

module WriteVTK

# All the code is based on the VTK file specification [1], plus some
# undocumented stuff found around the internet...
# [1] http://www.vtk.org/VTK/img/file-formats.pdf

export VTKCellTypes, VTKCellType
export MeshCell
export vtk_grid, vtk_save, vtk_point_data, vtk_cell_data
export vtk_multiblock
export paraview_collection, collection_add_timestep

using LightXML
using BufferedStreams: BufferedOutputStream, EmptyStreamSource
using Libz: ZlibDeflateOutputStream
import Compat.UTF8String

import Base: close, isopen

# Cell type definitions as in vtkCellType.h
include("VTKCellTypes.jl")

if VERSION >= v"0.5"
    Base.@deprecate_binding VTKCellType VTKCellTypes
else
    const VTKCellType = VTKCellTypes
end

## Constants ##
const COMPRESSION_LEVEL = 6
const IS_LITTLE_ENDIAN = (ENDIAN_BOM == 0x04030201)  # see the documentation for ENDIAN_BOM

## Types ##
abstract VTKFile

typealias DataBuffer BufferedOutputStream{EmptyStreamSource}

immutable DatasetFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    gridType_str::UTF8String
    Npts::Int           # Number of grid points.
    Ncls::Int           # Number of cells.
    compressed::Bool    # Data is compressed?
    appended::Bool      # Data is appended? (otherwise it's written inline, base64-encoded)
    buf::DataBuffer     # Buffer with appended data.
    function DatasetFile(xdoc, path, gridType_str, Npts, Ncls,
                         compressed, appended)
        buf = BufferedOutputStream() :: DataBuffer
        if !appended  # in this case we don't need a buffer
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
    # Constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

immutable CollectionFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    timeSteps::Vector{VTKFile}
    # Constructor.
    CollectionFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

# Cells in unstructured meshes.
immutable MeshCell
    ctype::VTKCellTypes.VTKCellType  # cell type identifier (see VTKCellTypes.jl)
    connectivity::Vector{Int32}      # indices of points (one-based, following the convention in Julia)
    function MeshCell{T<:Integer}(ctype::VTKCellTypes.VTKCellType,
                                  connectivity::Vector{T})
        if ctype.nodes ∉ (length(connectivity), -1)
            throw(ArgumentError("Wrong number of nodes in connectivity vector."))
        end
        return new(ctype, connectivity)
    end
end

close(vtk::VTKFile) = free(vtk.xdoc)
isopen(vtk::VTKFile) = (vtk.xdoc.ptr != C_NULL)

# Multiblock-specific functions and types.
include("gridtypes/multiblock.jl")
include("gridtypes/ParaviewCollection.jl")

# Grid-specific functions and types.
include("gridtypes/structured.jl")
include("gridtypes/unstructured.jl")
include("gridtypes/rectilinear.jl")
include("gridtypes/imagedata.jl")

# Common functions.
include("gridtypes/common.jl")

end
