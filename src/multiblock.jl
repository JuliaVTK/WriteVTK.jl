# Included in WriteVTK.jl

abstract VTKFile

immutable MultiblockFile <: VTKFile
    xdoc::XMLDocument
    path::UTF8String
    blocks::Vector{VTKFile}

    # Override default constructor.
    MultiblockFile(xdoc, path) = new(xdoc, path, VTKFile[])
end


function vtk_multiblock(filename_noext::AbstractString)
    # Initialise VTK multiblock file (extension .vtm).
    # filename_noext: filename without the extension (.vtm).

    xvtm = XMLDocument()
    xroot = create_root(xvtm, "VTKFile")
    atts = @compat Dict{UTF8String,UTF8String}(
        "type"       => "vtkMultiBlockDataSet",
        "version"    => "1.0",
        "byte_order" => "LittleEndian")
    set_attributes(xroot, atts)

    xMBDS = new_child(xroot, "vtkMultiBlockDataSet")

    return MultiblockFile(xvtm, string(filename_noext, ".vtm"))
end


function vtk_grid{T<:FloatingPoint}(
    vtm::MultiblockFile, x::Array{T}, y::Array{T}, z::Array{T};
    compress::Bool=true, append::Bool=true)
    #==========================================================================#
    # Creates a new grid file with coordinates x, y, z; and this file is
    # referenced as a block in the vtm file.
    #
    # See the documentation for the other variant of vtk_grid.
    #==========================================================================#

    # Multiblock file without the extension
    path_base = splitext(vtm.path)[1]

    # Dataset file without the extension
    vtsFilename_noext = @sprintf("%s.z%02d", path_base, 1 + length(vtm.blocks))

    vtk = vtk_grid(vtsFilename_noext, x, y, z, compress=compress)

    multiblock_add_block(vtm, vtk)

    return vtk::DatasetFile
end


function vtk_save(vtm::MultiblockFile)
    # Saves VTK multiblock file (.vtm).
    # Also saves the contained block files (vtm.blocks) recursively.

    outfiles = [vtm.path]::Vector{UTF8String}

    for vtk in vtm.blocks
        push!(outfiles, vtk_save(vtk)...)
    end

    save_file(vtm.xdoc, vtm.path)

    return outfiles::Vector{UTF8String}
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
    # This splits the filename and the directory name.
    fname = splitdir(vtk.path)[2]

    xDataSet = new_child(xBlock, "DataSet")
    atts = @compat Dict{UTF8String,UTF8String}(
                        "index" => "0", "file" => fname)
    set_attributes(xDataSet, atts)

    # Add the block file to vtm.
    push!(vtm.blocks, vtk)

    return
end

