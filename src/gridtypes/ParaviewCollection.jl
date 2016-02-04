function paraview_collection(filename_noext::AbstractString)
    # Initialise Paraview collection file (extension .pvd).
    # filename_noext: filename without the extension (.pvd).
    xpvd = XMLDocument()
    xroot = create_root(xpvd, "VTKFile")
    set_attribute(xroot, "type",       "Collection")
    set_attribute(xroot, "version",    "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
    new_child(xroot, "Collection")
    return CollectionFile(xpvd, string(filename_noext, ".pvd"))
end

function collection_add_timestep(pvd::CollectionFile, datfile::VTKFile,
                                 t::AbstractFloat)
  xroot = root(pvd.xdoc)
  xMBDS = find_element(xroot, "Collection")
  xDataSet = new_child(xMBDS, "DataSet")
  fname = splitdir(datfile.path)[2]
  set_attribute(xDataSet, "timestep", @sprintf("%f", t))
  set_attribute(xDataSet, "part", "0")
  set_attribute(xDataSet, "file", fname)
  push!(pvd.timeSteps, datfile)
  return
end

function vtk_save(pvd::CollectionFile)
    # Saves paraview collection file (.pvd).
    # Also saves the contained data files recursively.
    outfiles = [pvd.path]::Vector{UTF8String}
    for vtk in pvd.timeSteps
        append!(outfiles, vtk_save(vtk))
    end
    save_file(pvd.xdoc, pvd.path)
    return outfiles::Vector{UTF8String}
end
