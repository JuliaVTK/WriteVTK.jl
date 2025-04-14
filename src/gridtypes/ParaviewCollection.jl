"""
    CollectionFile <: VTKFile

Handler for a ParaView collection file (`.pvd`).
"""
struct CollectionFile <: VTKFile
    xdoc::XMLDocument
    path::String
    timeSteps::Vector{String}
    function CollectionFile(xdoc, path)
        finalizer(LightXML.free, xdoc)
        new(xdoc, path, String[])
    end
end

function paraview_collection(filename::AbstractString;
                             append=false) :: CollectionFile
    # Initialise Paraview collection file (extension .pvd).
    # filename: filename with or without the extension (.pvd).
    filename_full = add_extension(filename, ".pvd")

    if append && isfile(filename_full)
        # Append to existent PVD file.
        return paraview_collection_load(filename_full)
    end

    xpvd = XMLDocument()
    xroot = create_root(xpvd, "VTKFile")
    set_attribute(xroot, "type", "Collection")
    set_attribute(xroot, "version", "1.0")
    if IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end
    set_attribute(xroot, "compressor", "vtkZLibDataCompressor")
    new_child(xroot, "Collection")

    return CollectionFile(xpvd, filename_full)
end

function paraview_collection_load(filename::AbstractString)
    pvd_filename = add_extension(filename, ".pvd")
    xpvd = parse_file(pvd_filename)
    pvd = paraview_collection(filename)
    xroot = root(pvd.xdoc)
    xMBDS = find_element(xroot, "Collection")
    # Iterate the child elements and only add
    # attributes considered by pvd.
    # This also preserves the formatting of the resulting
    # file as the empty textnodes created during loading
    # are removed.
    for c in child_elements(find_element(root(xpvd), "Collection"))
        xDataSet = new_child(xMBDS, "DataSet")
        set_attribute(xDataSet, "timestep", attribute(c, "timestep"))
        set_attribute(xDataSet, "part", attribute(c, "part"))
        set_attribute(xDataSet, "file", attribute(c, "file"))
    end
    LightXML.free(xpvd)
    return pvd
end

function collection_add_timestep(pvd::CollectionFile, datfile::VTKFile,
                                 time::Real)
    xroot = root(pvd.xdoc)
    xMBDS = find_element(xroot, "Collection")
    xDataSet = new_child(xMBDS, "DataSet")
    fname = relpath(abspath(datfile.path), first(splitdir(abspath(pvd.path))))
    set_attribute(xDataSet, "timestep", string(time))
    set_attribute(xDataSet, "part", "0")
    set_attribute(xDataSet, "file", fname)
    append!(pvd.timeSteps, close(datfile))
    return
end

Base.setindex!(pvd::CollectionFile, datfile::VTKFile, time::Real) =
    collection_add_timestep(pvd, datfile, time)

function vtk_save(pvd::CollectionFile)
    outfiles = [pvd.path; pvd.timeSteps]::Vector{String}
    if isopen(pvd)
        LightXML.save_file(pvd.xdoc, pvd.path)
        close_xml(pvd)
    end
    return outfiles
end
