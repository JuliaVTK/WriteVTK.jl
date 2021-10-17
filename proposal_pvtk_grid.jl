#module ParallelDatasetFiles
  using WriteVTK
  using LightXML

  struct ParallelDatasetFile <: WriteVTK.VTKFile
    xdoc::XMLDocument
    path::AbstractString
    num_pieces::Integer
    ParallelDatasetFile(xdoc,path::AbstractString,num_pieces::Integer)=new(xdoc,path,num_pieces)
  end

  function WriteVTK.vtk_save(vtk::ParallelDatasetFile)
    if isopen(vtk)
        save_file(vtk.xdoc, vtk.path)
        close(vtk)
    end
    return [vtk.path] :: Vector{String}
  end

  function get_dataset_extension(dataset::WriteVTK.DatasetFile)
    path, ext = splitext(dataset.path)
    @assert ext != ""
    ext
  end

  function get_dataset_path(dataset::WriteVTK.DatasetFile)
    path, ext = splitext(dataset.path)
    @assert ext != ""
    path
  end

  function get_type(dataset::WriteVTK.DatasetFile)
    r=root(dataset.xdoc)
    attribute(r,"type")
  end

  function get_grid_element(dataset::WriteVTK.DatasetFile,
                            element::AbstractString)
     r=root(dataset.xdoc)
     uns=find_element(r,get_type(dataset))
     piece=find_element(uns,"Piece")
     find_element(piece,element)
  end

  function num_children(element)
    length(collect(child_elements(element)))
  end

  function get_child_attribute(element,child,attr)
    children=collect(child_elements(element))
    attribute(children[child],attr)
  end

  function set_attribute_if_valid_value(node,name,value)
    if (value!="nothing")
       set_attribute(node,name,value)
    end
  end

  function generate_pieces(grid_xml_node,
                           dataset::WriteVTK.DatasetFile,
                           num_pieces::Int)

     path=get_dataset_path(dataset)
     ext=get_dataset_extension(dataset)
     for i=1:num_pieces
       piece=new_child(grid_xml_node,"Piece")
       set_attribute(piece,"Source",path*string(i)*ext)
     end
     grid_xml_node
  end

  function pvtk_grid(dataset::WriteVTK.DatasetFile,
                     filename::AbstractString,
                     num_pieces::Integer;
                     ghost_level=0)

    # Initialise Paraview parallel file format (extension .pXXX).
    # filename: filename with or without the extension (.pvd).
    dataset_extension  = get_dataset_extension(dataset)
    pdataset_extension = ".p" * dataset_extension[2:end]
    filename_full      = WriteVTK.add_extension(filename, pdataset_extension)
    xpvtX = XMLDocument()
    xroot = create_root(xpvtX, "VTKFile")
    set_attribute(xroot, "type", "P"*get_type(dataset))
    set_attribute(xroot, "version", "1.0")
    if WriteVTK.IS_LITTLE_ENDIAN
        set_attribute(xroot, "byte_order", "LittleEndian")
    else
        set_attribute(xroot, "byte_order", "BigEndian")
    end

    # Generate parallel grid node
    grid_xml_node=new_child(xroot,"P"*get_type(dataset))
    set_attribute(grid_xml_node, "GhostLevel", string(ghost_level))

    # Generate PPoints
    ppoints=new_child(grid_xml_node,"PPoints")
    ppointsarray=new_child(ppoints,"PDataArray")
    points=get_grid_element(dataset,"Points")
    set_attribute(ppointsarray, "type",
                  get_child_attribute(points,1,"type"))
    set_attribute(ppointsarray, "NumberOfComponents",
                  get_child_attribute(points,1,"NumberOfComponents"))

    # Generate PPointData
    pointdata=get_grid_element(dataset,"PointData")
    if pointdata != nothing
      if (num_children(pointdata)>0)
        ppointdata=new_child(grid_xml_node,"PPointData")
        for child=1:num_children(pointdata)
          parray=new_child(ppointdata,"PDataArray")
          set_attribute(parray, "type",
                        get_child_attribute(pointdata,child,"type"))
          set_attribute(parray, "NumberOfComponents",
                        get_child_attribute(pointdata,child,"NumberOfComponents"))
          set_attribute(parray, "Name",
                       get_child_attribute(pointdata,child,"Name"))
        end
      end
    end

    # Generate PCellData
    celldata=get_grid_element(dataset,"CellData")
    if celldata!=nothing
      if (num_children(celldata)>0)
        ppointdata=new_child(grid_xml_node,"PCellData")
        for child=1:num_children(celldata)
          parray=new_child(ppointdata,"PDataArray")
          set_attribute(parray, "type",
                        get_child_attribute(celldata,child,"type"))
          set_attribute(parray, "Name",
                        get_child_attribute(celldata,child,"Name"))
          set_attribute_if_valid_value(parray, "NumberOfComponents",
                        get_child_attribute(celldata,child,"NumberOfComponents"))
        end
      end
    end

    # Generate pieces
    generate_pieces(grid_xml_node,dataset,num_pieces)

    ParallelDatasetFile(xpvtX,filename_full,num_pieces)
  end


  # Suppose that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellTypes.VTK_QUAD,     [2, 4, 3, 5])]

  x=rand(5)
  y=rand(5)
  vtkfile = vtk_grid("my_vtk_file", x, y, cells) # 2D
  vtkfile["Pressure"] = x
  pvtkfile=pvtk_grid(vtkfile,"simulation",2)
  vtk_save(pvtkfile)
  vtk_save(vtkfile)
#end
