module WriteVTK

# Documentation on VTK XML formats:
# - https://vtk.org/Wiki/VTK_XML_Formats
# - http://vtk.org/VTK/img/file-formats.pdf

export MeshCell
export vtk_grid, vtk_save, vtk_point_data, vtk_cell_data
export vtk_multiblock
export paraview_collection, collection_add_timestep, paraview_collection_load
export vtk_write_array
export VTKPointData, VTKCellData, VTKFieldData
export PolyData

import CodecZlib: ZlibCompressorStream
import TranscodingStreams

using LightXML
using FillArrays: Zeros

using Base64: base64encode

import Base: close, isopen, show

# Cell type definitions as in vtkCellType.h
include("VTKCellTypes.jl")
using .VTKCellTypes
export VTKCellTypes, VTKCellType

## Constants ##
const DEFAULT_COMPRESSION_LEVEL = 6
const IS_LITTLE_ENDIAN = ENDIAN_BOM == 0x04030201
const HeaderType = UInt64  # should be UInt32 or UInt64

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
    ascii::Bool         # if true, inline data is written in ASCII format (only used if `appended` is false)
    buf::IOBuffer       # Buffer with appended data.
    function DatasetFile(xdoc, path, grid_type, Npts, Ncls;
                         compress=true, append=true, ascii=false)
        clevel = _compression_level(compress)
        if !(0 ≤ clevel ≤ 9)
            throw(ArgumentError("unexpected value of `compress` argument: $compress.\n" *
                                "It must be a `Bool` or a value between 0 and 9."))
        end
        ascii = !append && ascii
        if ascii
            clevel = 0  # no compression when writing ASCII
        end
        buf = IOBuffer()
        if !append  # in this case we don't need a buffer
            close(buf)
        end
        new(xdoc, path, grid_type, Npts, Ncls, clevel, append, ascii, buf)
    end
end

DatasetFile(dtype, xdoc::XMLDocument, fname::AbstractString, args...; kwargs...) =
    DatasetFile(xdoc, add_extension(fname, dtype), xml_name(dtype), args...; kwargs...)

function show(io::IO, vtk::DatasetFile)
    open_str = isopen(vtk) ? "open" : "closed"
    print(io, "VTK file '$(vtk.path)' ($(vtk.grid_type) file, $open_str)")
end

struct MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::String
    blocks::Vector{VTKFile}
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

struct CollectionFile <: VTKFile
    xdoc::XMLDocument
    path::String
    timeSteps::Vector{String}
    CollectionFile(xdoc, path) = new(xdoc, path, VTKFile[])
end

"""
    close(vtk::VTKFile)

Write and close VTK file.
"""
close(vtk::VTKFile) = free(vtk.xdoc)

"""
    isopen(vtk::VTKFile)

Check if VTK file is still being written.
"""
isopen(vtk::VTKFile) = (vtk.xdoc.ptr != C_NULL)

# Add a default extension to the filename, unless the user have already given
# the correct one.
function add_extension(filename, default_extension::AbstractString) :: String
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

add_extension(filename, dtype) = add_extension(filename, file_extension(dtype))

# Common functions and types.
include("write_data.jl")
include("save_files.jl")
include("gridtypes/types.jl")
include("gridtypes/common.jl")

# Multiblock-specific functions and types.
include("gridtypes/multiblock.jl")
include("gridtypes/ParaviewCollection.jl")

# Grid-specific functions and types.
include("gridtypes/structured/imagedata.jl")
include("gridtypes/structured/rectilinear.jl")
include("gridtypes/structured/structured.jl")
include("gridtypes/unstructured/unstructured.jl")
include("gridtypes/unstructured/polydata.jl")

include("gridtypes/array.jl")

# This allows using do-block syntax for generation of VTK files.
for func in (:vtk_grid, :vtk_multiblock, :paraview_collection,
             :paraview_collection_load)
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
