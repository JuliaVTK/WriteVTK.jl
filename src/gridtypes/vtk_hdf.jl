using HDF5

abstract type VTKFileType end
struct VTKHDF5 <: VTKFileType end
struct VTKXML <: VTKFileType end

struct VTKHDFUnstructuredGrid <: UnstructuredVTKDataset end

struct VTKHDF5File <: VTKFile
    h5file # an HDF5.File
    version::AbstractString
    grid_type::AbstractString
    Npts::Int
    Ncls::Int
end

# for unstructured
struct VTKHDFTimeSeries{T<:AbstractFieldData}
    vtkhdf::VTKHDF5File
    name::AbstractString
end

# check if file is open
Base.isopen(file::VTKHDF5File) = isopen(file.h5file)

function Base.close(file::VTKHDF5File)
    if isopen(file)
        close(file.h5file)
    end
end

function vtk_grid(
    ::VTKHDF5,
    filename,
    points,
    cells;
    kws...)
    vtk_grid(
        VTKHDFUnstructuredGrid(),
        filename, points, cells; kws...)
end

function vtk_grid(
    dtype::VTKHDFUnstructuredGrid,
    filename::AbstractString,
    points::UnstructuredCoords,
    cells::CellVector;
    kwargs...)

    Npts = num_points(dtype, points)
    Ncls = length(cells)

    # need types, offsets, connectivity for unstructured
    # copied from unstructured.jl, but offset has a zero at the beginnining
    # for VTKHDF case 

    # vtk cell information
    IntType = connectivity_type(cells)::Type{<:Integer}
    # Create data arrays.
    offsets = Array{IntType}(undef, Ncls + 1)
    offsets[1] = 0

    types = Array{UInt8}(undef, Ncls)

    Nconn = 0     # length of the connectivity array
    if Ncls >= 1  # it IS possible to have no cells
        offsets[2] = length(cells[1].connectivity)
    end

    for (n, c) in enumerate(cells)
        Npts_cell = length(c.connectivity)
        Nconn += Npts_cell
        types[n] = cell_type(c).vtk_id
        if n >= 2
            offsets[n+1] = offsets[n] + Npts_cell
        end
    end

    # Create connectivity array.
    conn = Array{IntType}(undef, Nconn)
    n = 1
    for c in cells, i in c.connectivity
        # We transform to zero-based indexing, required by VTK.
        conn[n] = i - one(i)
        n += 1
    end

    h5file = h5open("$filename.vtkhdf", "w")

    # write attributes
    VTKHDF_group = create_group(h5file, "VTKHDF")
    HDF5.attributes(VTKHDF_group)["Version"] = [2, 0]

    type = "UnstructuredGrid"
    h5_dspace = HDF5.dataspace(type)
    h5_dtype = HDF5.datatype(type)
    HDF5.h5t_set_cset(h5_dtype, HDF5.H5T_CSET_ASCII)
    attr = create_attribute(VTKHDF_group, "Type", h5_dtype, h5_dspace)
    write_attribute(attr, h5_dtype, type)

    VTKHDF_group["NumberOfConnectivityIds"] = [Nconn]
    VTKHDF_group["NumberOfPoints"] = [Npts]
    VTKHDF_group["NumberOfCells"] = [Ncls]
    VTKHDF_group["Points"] = points
    VTKHDF_group["Types"] = types
    VTKHDF_group["Connectivity"] = conn
    VTKHDF_group["Offsets"] = offsets

    VTKHDF5File(h5file, "2.0", type, Npts, Ncls)
end

"""
Check for Steps group, maybe create it, and add to Steps.

Return VTKHDFTimeSeries

"""
function vtkhdf_open_timeseries(
    vtkhdf::VTKHDF5File,
    name::AbstractString,
    data_type::Union{VTKCellData,VTKPointData},
    vec_dim=1
)
    root = vtkhdf.h5file["VTKHDF"]

    if !haskey(root, "Steps")
        steps = create_group(root, "Steps")
        # initialize num_steps to zero
        num_steps = 0
        attrs(steps)["NSteps"] = num_steps

        create_dataset(steps, "Values", Float64, dataspace((0,), (-1,)), chunk=(100,))

        # offsets that are just all zeros
        create_dataset(steps, "PartOffsets", Int64, dataspace((0,), (-1,)), chunk=(100,))
        create_dataset(steps, "PointOffsets", Int64, dataspace((0,), (-1,)), chunk=(100,))
        create_dataset(steps, "CellOffsets", Int64, dataspace((0,), (-1,)), chunk=(100,))
        create_dataset(steps, "ConnectivityIdOffsets", Int64, dataspace((1, 0), (-1, -1)), chunk=(1, 100))
        create_dataset(steps, "NumberOfParts", Int64, dataspace((0,), (-1,)), chunk=(100,))
    else
        steps = root["Steps"]
    end

    # check for and maybe create CellDataOffsets of PointDataOffsets respectively
    if data_type isa VTKCellData
        if vec_dim == 1
            data_size = dataspace((0,), (-1,))
            chunk_size = (vtkhdf.Ncls,)
        else
            data_size = dataspace((vec_dim, 0), (-1, -1))
            chunk_size = (vec_dim, vtkhdf.Ncls)
        end

        # where data is stored
        if !haskey(root, "CellData")
            CellData = create_group(root, "CellData")
        else
            CellData = root["CellData"]
        end
        create_dataset(CellData, name, Float64, data_size, chunk=chunk_size)

        if !haskey(steps, "CellDataOffsets")
            CellDataOffsets = create_group(steps, "CellDataOffsets")
        else
            CellDataOffsets = steps["CellDataOffsets"]
        end
        # where offsets are stored
        create_dataset(CellDataOffsets, name, Int64, dataspace((0,), (-1,)), chunk=(100,))
    end

    if data_type isa VTKPointData
        if !haskey(root, "PointData")
            CellData = create_group(root, "PointData")
        else
            CellData = root["PointData"]
        end
        # where data is stored
        create_dataset(CellData, name, Float64, (0,))

        if !haskey(steps, "PointDataOffsets")
            PointDataOffsets = create_group(steps, "PointDataOffsets")
        else
            PointDataOffsets = steps["PointDataOffsets"]
        end
        create_dataset(PointDataOffsets, name, Int64, (0,))

    end

    VTKHDFTimeSeries{typeof(data_type)}(vtkhdf, name)
end

# check for vector case of size(N, M), instead  of size(N,)
# also handle chunking?
function append_and_resize(dset, array)
    dset_size, dset_max_size = HDF5.get_extent_dims(dset)

    array_dims = size(array)
    data_size = array_dims[end]
    prev_size = dset_size[end]

    # handle vector case, e.g. (3, N)
    if length(array_dims) == 2
        new_size = (array_dims[1], data_size + prev_size)
        HDF5.set_extent_dims(dset, new_size)
        dset[:, 1+prev_size:end] = array
    else
        new_size = (data_size + prev_size,)
        HDF5.set_extent_dims(dset, new_size)
        dset[1+prev_size:end] = array
    end
end

Base.setindex!(
    series::VTKHDFTimeSeries{VTKCellData},
    data,
    time::Float64
) = vtkhdf_append_timeseries_dataset(series, time, data)

function vtkhdf_append_timeseries_dataset(
    series::VTKHDFTimeSeries{VTKCellData},
    time::Float64,
    data
)
    root = series.vtkhdf.h5file["VTKHDF"]
    steps = root["Steps"]

    # append and resize the underlying datasets

    # CellDataOffsets, append previous offset + length(CellData)
    current_len = size(root["CellData"][series.name])[end]
    append_and_resize(steps["CellDataOffsets"][series.name], [current_len])
    # CellData, append 'data'
    append_and_resize(root["CellData"][series.name], data)

    # check the number of CellData datasets matches number of time steps
    num_datasets = current_len ÷ size(data)[end]

    if num_datasets == length(steps["Values"])
        # increment NSteps
        attrs(steps)["NSteps"] += 1

        # Values, append time
        append_and_resize(steps["Values"], [time])



        # PartOffsets, append 0
        append_and_resize(steps["PartOffsets"], [0])

        # PointOffsets, append 0
        append_and_resize(steps["PointOffsets"], [0])

        # CellOffsets, append 0
        append_and_resize(steps["CellOffsets"], [0])

        # ConnectivityIdOffsets, append 0
        append_and_resize(steps["ConnectivityIdOffsets"], [0][:, :])

        # NumberOfParts, append 1
        append_and_resize(steps["NumberOfParts"], [1])
    end # need some sort of reasonable else condition to see if time steps are in sync or not
end