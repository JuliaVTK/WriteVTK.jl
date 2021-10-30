# WriteVTK.jl

This package allows to write VTK XML files for visualisation of multidimensional
datasets using tools such as [ParaView](http://www.paraview.org/).
A wide range of VTK formats is supported, including different kinds of
structured and unstructured grids, as well as metadata files for describing
time series or multi-block domains.

## Quick start

The [`vtk_grid`](@ref) function is the entry point for creating different kinds
of VTK files.
In the simplest cases, one just passes coordinate information to this function.
WriteVTK.jl then determines the VTK format that is more adapted for the provided
data.

For instance, it is natural in Julia to describe a uniform three-dimensional
grid (with regularly-spaced increments) as a set of ranges:

```julia
x = 0:0.1:1
y = 0:0.2:1
z = -1:0.05:1
```

This specific way of specifying coordinates is compatible with the *image data*
VTK format, which have the `.vti` extension.
The following creates such a file, with some scalar data attached to each point:

```julia
vtk_grid("fields", x, y, z) do vtk
    vtk["temperature"] = rand(length(x), length(y), length(z))
end
```

This will create a `fields.vti` file with the data.
Note that the file extension should not be included in the filename, as it will
be attached automatically according to the dataset type.

By changing the coordinate specifications, the above can be naturally
generalised to non-uniform grid spacings and to curvilinear and unstructured
grids.
In each case, the correct kind of VTK file will be generated.

## Supported VTK formats

This package attempts to implement writers for all VTK XML formats described in the [VTK specification](http://www.vtk.org/VTK/img/file-formats.pdf).
Note that legacy (non-XML) files are not supported.

Supported dataset formats include:
- [image data](@ref Image-data) (`.vti`),
- [rectilinear grid](@ref Rectilinear-grid) (`.vtr`),
- [structured (or curvilinear) grid](@ref Structured-grid) (`.vts`),
- [unstructured grid](@ref Unstructured-grid) (`.vtu`),
- [polydata](@ref Polydata-grid) (`.vtp`, a specific type of unstructured grid).

Moreover, the following metadata formats are supported:
- multiblock grids (`.vtm`),
- ParaView collections (`.pvd`, typically used for time series),
- parallel formats (`.pvt*`, only partial support for now).

## Reading VTK files

The [ReadVTK.jl](https://github.com/trixi-framework/ReadVTK.jl) package, mainly written by [Michael Schlottke-Lakemper](https://www.mi.uni-koeln.de/NumSim/schlottke-lakemper) and the [Trixi authors](https://github.com/trixi-framework/Trixi.jl/blob/main/AUTHORS.md), may be used to read VTK files.
Note that ReadVTK.jl is specifically meant for reading VTK XML files generated
by WriteVTK.jl, and may not be able to read VTK files coming from other
sources.
See the [ReadVTK.jl documentation](https://github.com/trixi-framework/ReadVTK.jl#what-works) for
details on what can and cannot be done with it.
