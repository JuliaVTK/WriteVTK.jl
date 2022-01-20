function vtk_grid(
        dtype::VTKRectilinearGrid, filename::AbstractString,
        xs::Tuple{Vararg{AbstractVector, 3}};
        extent = map(length, xs), whole_extent = extent, kwargs...,
    )
    Ns = map(length, xs)
    Npts = prod(Ns)
    Ncls = num_cells_structured(Ns)

    xvtk = XMLDocument()
    vtk = DatasetFile(dtype, xvtk, filename, Npts, Ncls; kwargs...)

    # VTKFile node
    xroot = vtk_xml_write_header(vtk)

    # RectilinearGrid node
    xGrid = new_child(xroot, vtk.grid_type)
    let ext = extent_attribute(whole_extent)
        set_attribute(xGrid, "WholeExtent", ext)
    end

    # Piece node
    xPiece = new_child(xGrid, "Piece")
    let ext = extent_attribute(extent)
        set_attribute(xPiece, "Extent", ext)
    end

    # Coordinates node
    xPoints = new_child(xPiece, "Coordinates")

    # DataArray node
    x, y, z = xs
    data_to_xml(vtk, xPoints, x, "x")
    data_to_xml(vtk, xPoints, y, "y")
    data_to_xml(vtk, xPoints, z, "z")

    vtk
end

"""
    vtk_grid(filename::AbstractString,
             x::AbstractVector{T}, y::AbstractVector{T}, [z::AbstractVector{T}];
             kwargs...)

Create 2D or 3D rectilinear grid (`.vtr`) file.

Coordinates are specified by separate vectors `x`, `y`, `z`.

# Examples

```jldoctest
julia> vtk = vtk_grid("abc", [0., 0.2, 0.5], collect(-2.:0.2:3), [1., 2.1, 2.3])
VTK file 'abc.vtr' (RectilinearGrid file, open)
```

"""
function vtk_grid(
        filename::AbstractString,
        x::AbstractVector{T}, y::AbstractVector{T},
        z::AbstractVector{T} = Zeros{T}(1);
        kwargs...,
    ) where {T}
    vtk_grid(VTKRectilinearGrid(), filename, (x, y, z); kwargs...)
end
