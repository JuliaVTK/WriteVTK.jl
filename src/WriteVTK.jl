__precompile__()

module WriteVTK

# All the code is based on the VTK file specification [1], plus some
# undocumented stuff found around the internet...
# [1] http://www.vtk.org/VTK/img/file-formats.pdf

export VTKCellTypes, VTKCellType
export MeshCell
export vtk_grid, vtk_save, vtk_point_data, vtk_cell_data
export vtk_multiblock
export paraview_collection, collection_add_timestep, paraview_collection_load
export vtk_write_array

import CodecZlib: ZlibCompressorStream
import TranscodingStreams

using LightXML

using Base64: base64encode

import Base: close, isopen, show

# Cell type definitions as in vtkCellType.h
include("VTKCellTypes.jl")

## Constants ##
const DEFAULT_COMPRESSION_LEVEL = 6
const IS_LITTLE_ENDIAN = ENDIAN_BOM == 0x04030201

## Types ##
abstract type VTKFile end

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
    buf::IOBuffer       # Buffer with appended data.
    function DatasetFile(xdoc, path, grid_type, Npts, Ncls, compression,
                         appended)
        buf = IOBuffer()
        clevel = _compression_level(compression)
        if !(0 ≤ clevel ≤ 9)
            error("Unexpected value of `compress` argument: $compression.\n",
                  "It must be a `Bool` or a value between 0 and 9.")
        end
        if !appended  # in this case we don't need a buffer
            close(buf)
        end
        new(xdoc, path, grid_type, Npts, Ncls, clevel, appended, buf)
    end
end

function show(io::IO, vtk::DatasetFile)
    open_str = isopen(vtk) ? "open" : "closed"
    print(io, "VTK file '$(vtk.path)' ($(vtk.grid_type) file, $open_str)")
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

struct MeshCell{V <: AbstractVector{<:Integer}}
    ctype::VTKCellTypes.VTKCellType  # cell type identifier (see VTKCellTypes.jl)
    connectivity::V      # indices of points (one-based, following the convention in Julia)
    function MeshCell{V}(ctype::VTKCellTypes.VTKCellType, conn::V) where V
        if ctype.nodes ∉ (length(conn), -1)
            error("Wrong number of nodes in connectivity vector.")
        end
        new(ctype, conn)
    end
end

MeshCell(ctype, conn::V) where V = MeshCell{V}(ctype, conn)

close(vtk::VTKFile) = free(vtk.xdoc)
isopen(vtk::VTKFile) = (vtk.xdoc.ptr != C_NULL)

# Add a default extension to the filename,
# unless the user have already given the correct one
function add_extension(filename, default_extension) :: String
    path, ext = splitext(filename)
    if ext == default_extension
        return filename
    end
    if !isempty(ext)
        @warn("detected extension '$(ext)' does not correspond to " *
              "dataset type.\nAppending '$(default_extension)' to filename.")
    end
    filename * default_extension
end

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
        """
            $($func)(f::Function, args...; kwargs...)

        Create VTK file and apply `f` to it.
        The file is automatically closed by the end of the call.

        This allows to use the do-block syntax for creating VTK files:

        ```julia
        saved_files = $($func)(args...; kwargs...) do vtk
            # do stuff with the `vtk` file handler
        end
        ```
        """
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
