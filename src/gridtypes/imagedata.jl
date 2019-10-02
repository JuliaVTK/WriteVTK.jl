const TupleOrVec = Union{NTuple{N, T} where {N, T <: Real},
                         AbstractVector{T} where T <: Real}

function vtk_grid(filename::AbstractString,
                  Nx::Integer, Ny::Integer, Nz::Integer=1;
                  origin::TupleOrVec=(0.0, 0.0, 0.0),
                  spacing::TupleOrVec=(1.0, 1.0, 1.0),
                  compress=true, append::Bool=true, extent=nothing)
    Npts = Nx*Ny*Nz
    Ncls = num_cells_structured(Nx, Ny, Nz)
    ext = extent_attribute(Nx, Ny, Nz, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(xvtk, add_extension(filename, ".vti"), "ImageData",
                      Npts, Ncls, compress, append)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # ImageData node
    xGrid = new_child(xroot, vtk.grid_type)
    set_attribute(xGrid, "WholeExtent", ext)

    No = length(origin)
    Ns = length(spacing)

    if No > 3
        throw(ArgumentError("origin array must have length <= 3"))
    elseif Ns > 3
        throw(ArgumentError("spacing array must have length <= 3"))
    end

    origin_str = join(origin, " ")
    spacing_str = join(spacing, " ")

    while No != 3
        # Fill additional dimensions (e.g. the z dimension if 2D grid)
        origin_str *= (" 0.0")
        No += 1
    end

    while Ns != 3
        spacing_str *= (" 1.0")
        Ns += 1
    end

    set_attribute(xGrid, "Origin", origin_str)
    set_attribute(xGrid, "Spacing", spacing_str)

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    set_attribute(xPiece, "Extent", ext)

    return vtk::DatasetFile
end

"""
    vtk_grid(filename, x::AbstractRange{T}, y::AbstractRange{T}, z::AbstractRange{T};
             kwargs...)

Create image data (`.vti`) file.

Along each direction, the grid is specified in terms of an AbstractRange object.

# Examples

```jldoctest
julia> vtk = vtk_grid("abc", 1:0.2:5, 2:1.:3, 4:1.:5)
VTK file 'abc.vti' (ImageData file, open)

julia> vtk = vtk_grid("def",
                      LinRange(0., 5., 10),
                      LinRange(0., 2π, 16),
                      LinRange(1., 10., 12))
VTK file 'def.vti' (ImageData file, open)

```

"""
function vtk_grid(filename::AbstractString,
                  x::AbstractRange{T}, y::AbstractRange{T}, z::AbstractRange{T};
                  kwargs...) where T
    xyz = (x, y, z)
    Nxyz = map(length, xyz)
    origin = map(first, xyz)
    spacing = map(step, xyz)
    vtk_grid(filename, Nxyz; origin=origin, spacing=spacing, kwargs...)
end
