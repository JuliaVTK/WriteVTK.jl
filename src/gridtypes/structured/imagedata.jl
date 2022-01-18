function vtk_grid(
        dtype::VTKImageData, filename::AbstractString, Ns::Dims{N};
        origin::NTuple{N} = ntuple(d -> 0.0, Val(N)),
        spacing::NTuple{N} = ntuple(d -> 1.0, Val(N)),
        extent = nothing, kwargs...,
    ) where {N}
    Npts = prod(Ns)
    Ncls = num_cells_structured(Ns)
    ext = extent_attribute(Ns, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # ImageData node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    origin_str = _tuple_to_str3(origin, zero(eltype(origin)))
    spacing_str = _tuple_to_str3(spacing, one(eltype(origin)))

    set_attribute(xGrid, "Origin", origin_str)
    set_attribute(xGrid, "Spacing", spacing_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    vtk
end

_tuple_to_str3(ts::NTuple{3, T}, default::T) where {T} = join(ts, " ")

function _tuple_to_str3(ts::NTuple{N, T}, default::T) where {N, T}
    @assert N < 3
    M = 3 - N
    tt = (ts..., ntuple(d -> default, Val(M))...)
    _tuple_to_str3(tt, default)
end

function vtk_grid(filename::AbstractString, Ns::Vararg{Integer}; kwargs...)
    vtk_grid(filename, map(N -> 1:N, Ns)...; kwargs...)
end

"""
    vtk_grid(filename, x::AbstractRange{T}, y::AbstractRange{T}, [z::AbstractRange{T}];
             kwargs...)

Create image data (`.vti`) file.

Along each direction, the grid is specified in terms of an AbstractRange object.

# Examples

```jldoctest
julia> vtk = vtk_grid("abc", 1:0.2:5, 2:1.:3, 4:1.:5)  # 3D dataset
VTK file 'abc.vti' (ImageData file, open)

julia> vtk = vtk_grid("abc", 1:5, 2:1.:3, range(4, 5; length = 3))  # different kinds of ranges
VTK file 'abc.vti' (ImageData file, open)

julia> vtk = vtk_grid("abc", 1:0.2:5, 2:1.:3)  # 2D dataset
VTK file 'abc.vti' (ImageData file, open)

julia> vtk = vtk_grid("def",
                      LinRange(0., 5., 10),
                      LinRange(0., 2π, 16),
                      LinRange(1., 10., 12))
VTK file 'def.vti' (ImageData file, open)

```

"""
function vtk_grid(filename::AbstractString, xyz::Vararg{AbstractRange}; kwargs...)
    Nxyz = length.(xyz)
    origin = first.(xyz)
    spacing = step.(xyz)
    vtk_grid(VTKImageData(), filename, Nxyz;
             origin=origin, spacing=spacing, kwargs...)
end
