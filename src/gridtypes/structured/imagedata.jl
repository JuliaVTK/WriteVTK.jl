function vtk_grid(dtype::VTKImageData, filename::AbstractString,
                  Nx::Integer, Ny::Integer, Nz::Integer=1;
                  origin = (0.0, 0.0, 0.0),
                  spacing = (1.0, 1.0, 1.0),
                  extent = nothing, kwargs...)
    Npts = Nx*Ny*Nz
    Ncls = num_cells_structured(Nx, Ny, Nz)
    ext = extent_attribute(Nx, Ny, Nz, extent)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

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

    vtk
end

vtk_grid(filename::AbstractString, xyz::Vararg{Integer}; kwargs...) =
    vtk_grid(VTKImageData(), filename, xyz...; kwargs...)

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
    vtk_grid(VTKImageData(), filename, Nxyz...;
             origin=origin, spacing=spacing, kwargs...)
end
