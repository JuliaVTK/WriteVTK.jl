using WriteVTK
using LightXML

struct PVTKLayout
  part::Int
  nparts::Int
  ismain::Bool
end
# By default, we assume that part 1 is the main part
PVTKLayout(part,nparts) = PVTKLayout(part,nparts,part==1)


struct ParallelDatasetFile <: WriteVTK.VTKFile
  layout::PVTKLayout
  xdoc::XMLDocument
  dataset::WriteVTK.DatasetFile
  path::AbstractString
  function ParallelDatasetFile(layout::PVTKLayout,
                               xdoc::XMLDocument,
                               dataset::WriteVTK.DatasetFile,
                               path::AbstractString)
    new(layout,xdoc,dataset,path)
  end
end

function WriteVTK.vtk_save(vtk::ParallelDatasetFile)
  if isopen(vtk)
    _pvtk_grid_body(vtk)
    if vtk.layout.ismain
       save_file(vtk.xdoc, vtk.path)
    end
    vtk_save(vtk.dataset)
    close(vtk)
  end
  return [vtk.path] :: Vector{String}
end

function new_pdata_array(xParent,
                         type::Type{<:WriteVTK.VTKDataType},
                         name::AbstractString,
                         Nc=nothing)
  xDA = new_child(xParent, "PDataArray")
  set_attribute(xDA, "type", WriteVTK.datatype_str(type))
  set_attribute(xDA, "Name", name)
  if Nc != nothing
    set_attribute(xDA, "NumberOfComponents", Nc)
  end
end

function get_extension(filename::AbstractString)
  path, ext = splitext(filename)
  ext
end

function get_path(filename::AbstractString)
  path, ext = splitext(filename)
  path
end

function parallel_file_extension(g::WriteVTK.AbstractVTKDataset)
  ext=WriteVTK.file_extension(g)
  replace(ext,"."=>".p")
end

function parallel_xml_name(g::WriteVTK.AbstractVTKDataset)
  "P"*WriteVTK.xml_name(g)
end

function parallel_xml_write_header(pvtx::XMLDocument,dtype::WriteVTK.AbstractVTKDataset)
  xroot = create_root(pvtx, "VTKFile")
  set_attribute(xroot, "type", parallel_xml_name(dtype))
  set_attribute(xroot, "version", "1.0")
  if WriteVTK.IS_LITTLE_ENDIAN
    set_attribute(xroot, "byte_order", "LittleEndian")
  else
    set_attribute(xroot, "byte_order", "BigEndian")
  end
  xroot
end

function add_pieces!(grid_xml_node,
                     prefix::AbstractString,
                     extension::AbstractString,
                     num_pieces::Int)
  for i=1:num_pieces
    piece=new_child(grid_xml_node,"Piece")
    set_attribute(piece,"Source",prefix*string(i)*extension)
  end
  grid_xml_node
end

function add_ppoints!(grid_xml_node;
                      type::Type{<:WriteVTK.VTKDataType}=Float64)
  ppoints=new_child(grid_xml_node,"PPoints")
  new_pdata_array(ppoints,type,"Points",3)
end

function add_ppoint_data!(pdataset::ParallelDatasetFile,
                          name::AbstractString;
                          type::Type{<:WriteVTK.VTKDataType}=Float64,
                          Nc::Integer=1)
  xroot=root(pdataset.xdoc)
  dtype = xml_name_to_VTK_Dataset(pdataset.dataset.grid_type)
  grid_xml_node=find_element(xroot,parallel_xml_name(dtype))
  @assert grid_xml_node != nothing
  grid_xml_node_ppoint=find_element(grid_xml_node,"PPointData")
  if (grid_xml_node_ppoint==nothing)
    grid_xml_node_ppoint=new_child(grid_xml_node,"PPointData")
  end
  new_pdata_array(grid_xml_node_ppoint,type,name,Nc)
end

function add_pcell_data!(pdataset::ParallelDatasetFile,
                         name::AbstractString;
                         type::Type{<:WriteVTK.VTKDataType}=Float64,
                         Nc=nothing)
  xroot=root(pdataset.xdoc)
  dtype = xml_name_to_VTK_Dataset(pdataset.dataset.grid_type)
  grid_xml_node=find_element(xroot,parallel_xml_name(dtype))
  @assert grid_xml_node != nothing
  grid_xml_node_pcell=find_element(grid_xml_node,"PCellData")
  if (grid_xml_node_pcell==nothing)
    grid_xml_node_pcell=new_child(grid_xml_node,"PCellData")
  end
  new_pdata_array(grid_xml_node_pcell,type,name,Nc)
end

function Base.setindex!(pvtk::ParallelDatasetFile,
                        data,
                        name::AbstractString,
                        loc::WriteVTK.AbstractFieldData)
  pvtk.dataset[name,loc]=data
end

function Base.setindex!(vtk::ParallelDatasetFile, data, name::AbstractString)
  pvtk.dataset[name]=data
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

function xml_name_to_VTK_Dataset(xml_name::AbstractString)
    if (xml_name=="ImageData")
      WriteVTK.VTKImageData()
    elseif (xml_name=="RectilinearGrid")
      WriteVTK.VTKRectilinearGrid()
    elseif (xml_name=="PolyData")
      WriteVTK.VTKPolyData()
    elseif (xml_name=="StructuredGrid")
      WriteVTK.VTKStructuredGrid()
    elseif (xml_name=="UnstructuredGrid")
      WriteVTK.VTKUnstructuredGrid()
    else
      @assert false
    end
end

function num_children(element)
  length(collect(child_elements(element)))
end

function get_child_attribute(element,child,attr)
  children=collect(child_elements(element))
  attribute(children[child],attr)
end

function get_dataset_xml_type(dataset::WriteVTK.DatasetFile)
  r=root(dataset.xdoc)
  attribute(r,"type")
end

function get_dataset_xml_grid_element(dataset::WriteVTK.DatasetFile,
                                      element::AbstractString)
   r=root(dataset.xdoc)
   uns=find_element(r,get_dataset_xml_type(dataset))
   piece=find_element(uns,"Piece")
   find_element(piece,element)
end


const string_to_VTKDataType = Dict("Int8"=>Int8,
                                   "UInt8"=>UInt8,
                                   "Int16"=>Int16,
                                   "UInt16"=>UInt16,
                                   "Int32"=>Int32,
                                   "UInt32"=>UInt32,
                                   "Int64"=>Int64,
                                   "UInt64"=>UInt64,
                                   "Float32"=>Float32,
                                   "Float64"=>Float64,
                                   "String"=>String)

function pvtk_grid(layout::PVTKLayout,args...;ghost_level=0,kwargs...)
  filename=args[1]
  path, ext = splitext(filename)
  bname=basename(path)
  path = mkpath(path)
  filename=joinpath(path,bname*string(layout.part)*ext)
  vtk=vtk_grid((filename,args[2:end]...)...;kwargs...)
  _pvtk_grid_header(layout,vtk,path;ghost_level=ghost_level)
end

"""
"""
function _pvtk_grid_header(
                   layout::PVTKLayout,
                   dataset::WriteVTK.DatasetFile,
                   filename::AbstractString;
                   ghost_level=0)

    pvtx  = XMLDocument()
    dtype = xml_name_to_VTK_Dataset(dataset.grid_type)
    xroot = parallel_xml_write_header(pvtx,dtype)

    # Generate parallel grid node
    grid_xml_node=new_child(xroot,"P"*dataset.grid_type)
    set_attribute(grid_xml_node, "GhostLevel", string(ghost_level))

    prefix=joinpath(filename,basename(filename))
    extension=WriteVTK.file_extension(dtype)
    add_pieces!(grid_xml_node,prefix,extension,layout.nparts)

    pextension = parallel_file_extension(dtype)
    pfilename = WriteVTK.add_extension(filename,pextension)
    pdataset=ParallelDatasetFile(layout,pvtx,dataset,pfilename)

    # Generate PPoints
    points=get_dataset_xml_grid_element(dataset,"Points")
    type=get_child_attribute(points,1,"type")
    add_ppoints!(grid_xml_node,type=string_to_VTKDataType[type])

    pdataset
  end

function _pvtk_grid_body(pdataset::ParallelDatasetFile)
    dataset=pdataset.dataset
    # Generate PPointData
    pointdata=get_dataset_xml_grid_element(dataset,"PointData")
    if pointdata != nothing
      if (num_children(pointdata)>0)
        for child=1:num_children(pointdata)
          name=get_child_attribute(pointdata,child,"Name")
          type=get_child_attribute(pointdata,child,"type")
          Nc=get_child_attribute(pointdata,child,"NumberOfComponents")
          add_ppoint_data!(pdataset,
                           name;
                           type=string_to_VTKDataType[type],
                           Nc=parse(Int64,Nc))
        end
      end
    end

    # Generate PCellData
    celldata=get_dataset_xml_grid_element(dataset,"CellData")
    if celldata!=nothing
      if (num_children(celldata)>0)
        for child=1:num_children(celldata)
          name=get_child_attribute(celldata,child,"Name")
          type=get_child_attribute(celldata,child,"type")
          Nc=get_child_attribute(celldata,child,"NumberOfComponents")
          add_pcell_data!(pdataset,
                          name;
                          type=string_to_VTKDataType[type],
                          Nc=(Nc==nothing ? nothing : parse(Int64,Nc)))
        end
      end
    end
    pdataset
  end

# Suppose that the mesh is made of 5 points:
cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
         MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5])]
x=rand(5)
y=rand(5)

layout=PVTKLayout(1,1)
pvtk = pvtk_grid(layout,"simulation", x, y, cells) # 2D
pvtk["Pressure"] = x
pvtk["Processor"] = rand(2)
vtk_save(pvtk)
