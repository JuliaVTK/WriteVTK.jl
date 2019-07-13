function vtk_multiblock(filename::AbstractString)
    # Initialise VTK multiblock file (extension .vtm).
    # filename: filename with or without the extension (.vtm).
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
    multiblock_add_block(vtm, vtk)
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
    # Saves VTK multiblock file (.vtm).
    # Also saves the contained block files (vtm.blocks) recursively.
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

function multiblock_add_block(vtm::MultiblockFile, vtk::VTKFile)
    # Add VTK file as a new block to a multiblock file.

    # Find vtkMultiBlockDataSet node
    xroot = root(vtm.xdoc)
    xMBDS = find_element(xroot, "vtkMultiBlockDataSet")

    # Block node
    xBlock = new_child(xMBDS, "Block")
    nblock = length(vtm.blocks)
    set_attribute(xBlock, "index", "$nblock")

    # DataSet node
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(xBlock, "DataSet")
    set_attribute(xDataSet, "index", "0")
    set_attribute(xDataSet, "file",  fname)

    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    return
end
