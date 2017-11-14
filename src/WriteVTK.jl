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
export vtk_write_array

using LightXML
using BufferedStreams: BufferedOutputStream, EmptyStream
using Libz: ZlibDeflateOutputStream

import Base: close, isopen

# Cell type definitions as in vtkCellType.h
include("VTKCellTypes.jl")

Base.@deprecate_binding VTKCellType VTKCellTypes

## Constants ##
const DEFAULT_COMPRESSION_LEVEL = 6
const IS_LITTLE_ENDIAN = ENDIAN_BOM == 0x04030201

## Types ##
abstract type VTKFile end

const DataBuffer = BufferedOutputStream{EmptyStream}

_compression_level(x::Bool) = x ? DEFAULT_COMPRESSION_LEVEL : 0
_compression_level(x) = Int(x)

struct DatasetFile <: VTKFile
    xdoc::XMLDocument
    path::String
    grid_type::String
    Npts::Int           # Number of grid points.
    Ncls::Int           # Number of cells.
    compression_level::Int  # Compression level for zlib (if 0, compression is disabled)
    appended::Bool      # Data is appended? (otherwise it's written inline, base64-encoded)
    buf::DataBuffer     # Buffer with appended data.
    function DatasetFile(xdoc, path, grid_type, Npts, Ncls, compression,
                         appended)
        buf = BufferedOutputStream(EmptyStream())
        if !appended  # in this case we don't need a buffer
            close(buf)
        end
        clevel = _compression_level(compression)
        if !(0 ≤ clevel ≤ 9)
            error("Unexpected value of `compress` argument: $compression.\n",
                  "It must be a `Bool` or a value between 0 and 9.")
        end
        new(xdoc, path, grid_type, Npts, Ncls, clevel, appended, buf)
    end
end

struct MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::String
    blocks::Vector{VTKFile}
    # Constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

struct CollectionFile <: VTKFile
    xdoc::XMLDocument
    path::String
    timeSteps::Vector{String}
    # Constructor.
    CollectionFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

# Cells in unstructured meshes.
struct MeshCell
    ctype::VTKCellTypes.VTKCellType  # cell type identifier (see VTKCellTypes.jl)
    connectivity::Vector{Int32}      # indices of points (one-based, following the convention in Julia)
    function MeshCell(ctype::VTKCellTypes.VTKCellType,
                      connectivity::Vector{T}) where T<:Integer
        if ctype.nodes ∉ (length(connectivity), -1)
            throw(ArgumentError("Wrong number of nodes in connectivity vector."))
        end
        new(ctype, connectivity)
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
include("gridtypes/array.jl")

# Common functions.
include("gridtypes/common.jl")

# This allows using do-block syntax for generation of VTK files.
for func in (:vtk_grid, :vtk_multiblock, :paraview_collection)
    @eval begin
        function ($func)(f::Function, args...; kwargs...)
            vtk = ($func)(args...; kwargs...)
            local outfiles
            try
                f(vtk)
            finally
                outfiles = vtk_save(vtk)
            end
            outfiles :: Vector{String}
        end
    end
end

end
