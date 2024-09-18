"""
    VTKBlock

Handler for a nested block in a multiblock file.
"""
struct VTKBlock
    xelm::XMLElement
    blocks::Vector{Union{VTKFile,VTKBlock}}
    # Constructor.
    VTKBlock(xelm) = new(xelm, Union{VTKFile,VTKBlock}[])
end

Base.close(vtb::VTKBlock) = vtk_save(vtb)
xml_block_root(vtb::VTKBlock) = vtb.xelm

"""
    MultiblockFile <: VTKFile

Handler for a multiblock VTK file (`.vtm`).
"""
struct MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::String
    blocks::Vector{Union{VTKFile,VTKBlock}}
    function MultiblockFile(xdoc, path)
        finalizer(LightXML.free, xdoc)
        new(xdoc, path, Union{VTKFile,VTKBlock}[])
    end
end

function xml_block_root(vtm::MultiblockFile)
    # Find vtkMultiBlockDataSet node
    xroot = root(vtm.xdoc)
    find_element(xroot, "vtkMultiBlockDataSet")
end

const AnyBlock = Union{VTKBlock, MultiblockFile}

"""
    vtk_multiblock([f::Function], filename) -> MultiblockFile

Initialise VTK multiblock file, linking multiple VTK dataset files.

Returns a handler for a multiblock file.
To recursively save the multiblock file and linked dataset files, call
[`close`](@ref) on the returned handler.

Note that `close` is implicitly called if the optional `f` argument is passed.
This is in particular what happens when using the do-block syntax.
"""
function vtk_multiblock(filename::AbstractString)
    xvtm = XMLDocument()
    xroot = create_root(xvtm, "VTKFile")
    set_attribute(xroot, "type", "vtkMultiBlockDataSet")
    set_attribute(xroot, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    new_child(xroot, "vtkMultiBlockDataSet")
    MultiblockFile(xvtm, add_extension(filename, ".vtm"))
end

"""
    vtk_grid(vtm::Union{MultiblockFile, VTKBlock}, [filename], griddata...; kwargs...)

Create new dataset file that is added to an existent multiblock file.
The VTK grid is specified by the elements of `griddata`.

If the filename is not given, it is determined automatically from the filename
associated to `vtm` and the number of existent blocks.
"""
function vtk_grid(vtm::AnyBlock, vtk_filename::AbstractString,
                  griddata...; kwargs...)
    vtk = vtk_grid(vtk_filename, griddata...; kwargs...)
    # I'm not sure why these two cases should be different... It would probably
    # be OK to always pass the filename.
    if vtm isa MultiblockFile
        multiblock_add_block(vtm, vtk)
    elseif vtm isa VTKBlock
        multiblock_add_block(vtm, vtk, vtk_filename)
    end
    vtk
end

function vtk_grid(vtm::AnyBlock, griddata...; kwargs...)
    vtk_basename = _generate_gridfile_basename(vtm)
    vtk_grid(vtm, vtk_basename, griddata...; kwargs...)
end

function _generate_gridfile_basename(vtm::MultiblockFile)
    new_block_number = length(vtm.blocks) + 1
    block_name, _ = splitext(vtm.path)
    "$(block_name)_$(new_block_number)"
end

function _generate_gridfile_basename(vtm::VTKBlock)
    new_block_number = length(vtm.blocks) + 1
    xroot = xml_block_root(vtm)
    block_name = attribute(xroot, "name"; required = false)
    if block_name !== nothing
        "$(block_name)_$(new_block_number)"
    else
        block_index = attribute(xroot, "index")
        "block$(block_index)_$(new_block_number)"
    end
end

function vtk_save(vtm::MultiblockFile)
    outfiles = [vtm.path]::Vector{String}
    for vtk in vtm.blocks
        append!(outfiles, close(vtk))
    end
    if isopen(vtm)
        LightXML.save_file(vtm.xdoc, vtm.path)
        close_xml(vtm)
    end
    outfiles
end

function vtk_save(vtm::VTKBlock)
    # Saves VTKBlocks.
    outfiles = String[]
    for vtk in vtm.blocks
        append!(outfiles, close(vtk))
    end
    return outfiles
end

"""
    multiblock_add_block(
        vtm::Union{MultiblockFile, VTKBlock},
        vtk::VTKFile,
        [name = ""],
    ) -> nothing

Add a block to a [`MultiblockFile`](@ref) or a [`VTKBlock`](@ref).

---

    multiblock_add_block(
        vtm::Union{MultiblockFile, VTKBlock},
        [name = ""],
    ) -> VTKBlock

Create a sub-block in a [`MultiblockFile`](@ref) or a [`VTKBlock`](@ref).

Returns a new [`VTKBlock`](@ref).

"""
function multiblock_add_block end

function multiblock_add_block(vtm::AnyBlock, vtk::VTKFile, name="")
    # Add VTK file as a new block to a multiblock file or to a nested block.
    xroot = xml_block_root(vtm)

    # DataSet node
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(xroot, "DataSet")
    nblock = length(vtm.blocks)
    set_attribute(xDataSet, "index", string(nblock))
    set_attribute(xDataSet, "file", fname)
    if !isempty(name)
        set_attribute(xDataSet, "name", name)
    end

    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    nothing
end

function multiblock_add_block(vtm::AnyBlock, name="")
    xroot = xml_block_root(vtm)
    xBlock = new_child(xroot, "Block")
    nblock = length(vtm.blocks)
    set_attribute(xBlock, "index", string(nblock))
    if name != ""
        set_attribute(xBlock, "name",  name)
    end

    # Create the new block.
    block = VTKBlock(xBlock)

    # Add the block to vtm.
    push!(vtm.blocks, block)

    # Return the new block so the user can add VTKFiles or VTKBlocks under it,
    # if desired.
    block
end
