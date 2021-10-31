# WriteVTK

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jipolanco.github.io/WriteVTK.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jipolanco.github.io/WriteVTK.jl/dev/)
[![DOI](https://zenodo.org/badge/32700186.svg)](https://zenodo.org/badge/latestdoi/32700186)

[![Build Status](https://github.com/jipolanco/WriteVTK.jl/workflows/CI/badge.svg)](https://github.com/jipolanco/WriteVTK.jl/actions)
[![Coverage](https://codecov.io/gh/jipolanco/WriteVTK.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jipolanco/WriteVTK.jl)

This package allows to write VTK XML files for visualisation of multidimensional
datasets using tools such as [ParaView](http://www.paraview.org/).
A wide range of VTK formats is supported, including different kinds of
structured and unstructured grids, as well as metadata files for describing
time series or multi-block domains.

## Installation

WriteVTK can be installed using the Julia package manager:

```julia
julia> ] add WriteVTK
```

## Quick start

The `vtk_grid` function is the entry point for creating different kinds of VTK
files.
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
VTK format (.vti files).
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

This package attempts to implement writers for all VTK XML formats described in
the [VTK specification](http://www.vtk.org/VTK/img/file-formats.pdf).
Note that legacy (non-XML) files are not supported.

Supported dataset formats include:
- [image data](@ref Image-data) (`.vti`),
- [rectilinear grid](@ref Rectilinear-grid) (`.vtr`),
- [structured (or curvilinear) grid](@ref Structured-grid) (`.vts`),
- [unstructured grid](@ref Unstructured-grid) (`.vtu`),
- [polydata](@ref Polydata-grid) (`.vtp`, a specific type of unstructured grid).

Moreover, the following metadata formats are supported:
- [multiblock files](@ref Multiblock-files) (`.vtm`),
- [ParaView collections](@ref ParaView-collections) (`.pvd`, typically used for time series),
- [parallel files](@ref Parallel-files) (`.pvt*`, only partial support for now).

## Authors

This package is mainly written and maintained by [Juan Ignacio
Polanco](https://jipolanco.gitlab.io), with many important contributions by
[Fredrik Ekre](https://fredrikekre.se).
Moreover, a number of authors have implemented additional functionality, and
are acknowledged throughout the documentation.
