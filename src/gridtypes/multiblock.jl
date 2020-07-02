# Initialise VTK multiblock file (extension .vtm).
# filename: filename with or without the extension (.vtm).
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
    return MultiblockFile(xvtm, add_extension(filename, ".vtm"))
end

"""
    vtk_grid(vtm::MultiblockFile, [filename], griddata...; kwargs...)

Create new dataset file that is added to an existent multiblock file.
The VTK grid is specified by the elements of `griddata`.

If the filename is not given, it is determined automatically from the filename
of the vtm file and the number of existent blocks.
"""
function vtk_grid(vtm::MultiblockFile, vtk_filename::AbstractString,
                  griddata...; kwargs...)
    vtk = vtk_grid(vtk_filename, griddata...; kwargs...)
    push!(vtm, vtk)
    vtk :: DatasetFile
end

function vtk_grid(vtm::MultiblockFile, griddata...; kwargs...)
    vtm_basename, _ = splitext(vtm.path)
    vtk_basename = string(vtm_basename, "_", 1 + length(vtm.blocks))
    vtk_grid(vtm, vtk_basename, griddata...; kwargs...)
end

"""
    vtk_save(vtm::MultiblockFile)

Save and close multiblock file (.vtm).
The VTK files included in the multiblock file are also saved.
"""
function vtk_save(vtm::MultiblockFile)
    outfiles = [vtm.path]::Vector{String}
    for vtk in vtm.blocks
        append!(outfiles, vtk_save(vtk))
    end
    if isopen(vtm)
        save_file(vtm.xdoc, vtm.path)
        close(vtm)
    end
    return outfiles
end

function vtk_save(vtm::VTKBlock)
    # Saves VTKBlocks.
    outfiles = String[]
    for vtk in vtm.blocks
        append!(outfiles, vtk_save(vtk))
    end
    return outfiles
end

function multiblock_add_block(vtm::MultiblockFile, vtk::VTKFile, name="")
    # Add VTK file as a new block to a multiblock file.

    # Find vtkMultiBlockDataSet node
    xroot = root(vtm.xdoc)
    xMBDS = find_element(xroot, "vtkMultiBlockDataSet")

    # DataSet node
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(xMBDS, "DataSet")
    nblock = length(vtm.blocks)
    set_attribute(xDataSet, "index", "$nblock")
    set_attribute(xDataSet, "file",  fname)
    if name != ""
        set_attribute(xDataSet, "name",  name)
    end

    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    nothing
end

function multiblock_add_block(vtm::MultiblockFile, name="")
    # Add VTK block to a multiblock file.

    # Find vtkMultiBlockDataSet node
    xroot = root(vtm.xdoc)
    xMBDS = find_element(xroot, "vtkMultiBlockDataSet")

    # Add the block metadata to the XML.
    xBlock = new_child(xMBDS, "Block")
    nblock = length(vtm.blocks)
    set_attribute(xBlock, "index", "$nblock")
    if name != ""
        set_attribute(xBlock, "name",  name)
    end

    # Create the new block.
    block = VTKBlock(xBlock)

    # Add the block to vtm.
    push!(vtm.blocks, block)

    # Return the new block so the user can add VTKFiles or VTKBlocks under it,
    # if desired.
    return block
end

function multiblock_add_block(vtm::VTKBlock, vtk::VTKFile, name="")
    # Add VTKFile to a VTKBlock.

    # DataSet node
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(vtm.xelm, "DataSet")
    nblock = length(vtm.blocks)
    set_attribute(xDataSet, "index", "$nblock")
    set_attribute(xDataSet, "file",  fname)
    if name != ""
        set_attribute(xDataSet, "name",  name)
    end

    # Add the block to vtm.
    push!(vtm.blocks, vtk)

    nothing
end

function multiblock_add_block(vtm::VTKBlock, name="")
    # Add VTK block to a VTK Block.

    xBlock = new_child(vtm.xelm, "Block")
    nblock = length(vtm.blocks)
    set_attribute(xBlock, "index", "$nblock")
    if name != ""
        set_attribute(xBlock, "name",  name)
    end

    # Create the new block.
    block = VTKBlock(xBlock)

    # Add the block to vtm.
    push!(vtm.blocks, block)

    # Return the new block so the user can add VTKFiles or VTKBlocks under it,
    # if desired.
    return block
end

Base.push!(vtm::MultiblockFile, vtk::VTKFile) = multiblock_add_block(vtm, vtk)
