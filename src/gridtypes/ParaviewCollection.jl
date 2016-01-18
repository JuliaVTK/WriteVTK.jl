function paraview_collection(filename_noext::AbstractString)
      # Initialise VTK multiblock file (extension .vtm).
    # filename_noext: filename without the extension (.vtm).

    xvtm = XMLDocument()
    xroot = create_root(xvtm, "VTKFile")
    set_attribute(xroot, "type",       "Collection")
    set_attribute(xroot, "version",    "1.0")
    set_attribute(xroot, "byte_order", "LittleEndian")
    set_attribute(xroot, "compressor", "vtkZLibDataCompressor")

    xMBDS = new_child(xroot, "Collection")

    return CollectionFile(xvtm, string(filename_noext, ".pvd"))
end

function collection_add_timestep(pvd::CollectionFile,datfile::VTKFile,t::FloatingPoint)
  xroot = root(pvd.xdoc)
  xMBDS = find_element(xroot, "Collection")
  
  #Create dataset node
  xDataSet = new_child(xMBDS, "DataSet")
  fname = splitdir(datfile.path)[2] # This splits the filename and the directory name.
  set_attribute(xDataSet,"timestep",@sprintf("%f",t))
  set_attribute(xDataSet,"part","0")
  set_attribute(xDataSet,"file",fname)
  
  push!(pvd.timeSteps,datfile)
  return
end

function vtk_save(pvd::CollectionFile)
    # Saves paraview collection file (.pvd).
    # Also saves the contained data files recursively.
    outfiles = [pvd.path]::Vector{UTF8String}
    for vtk in pvd.timeSteps
        push!(outfiles, vtk_save(vtk)...)
    end
    save_file(pvd.xdoc, pvd.path)
    return outfiles::Vector{UTF8String}
end
