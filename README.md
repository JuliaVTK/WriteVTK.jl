# WriteVTK

[![Build Status](https://travis-ci.org/jipolanco/WriteVTK.jl.svg?branch=master)](https://travis-ci.org/jipolanco/WriteVTK.jl)

This module allows to write VTK XML files, that can be visualised for example
with [ParaView](http://www.paraview.org/).

The data is written compressed by default, using the
[Zlib](https://github.com/dcjones/Zlib.jl) package.

For the moment, only rectilinear (.vtr) and structured (.vts) grids are
supported.
Multiblock files (.vtm), which can point to multiple VTK files, can also be
exported.
Support for unstructured meshes is planned.

## Usage

### Create a grid

The function `vtk_grid` initialises the VTK file.
This function requires a filename with no extension, and the grid coordinates.
Depending on the shape of the arrays `x`, `y` and `z`, either a rectilinear or
structured grid is created.

```julia
vtkfile = vtk_grid("my_vtk_file", x, y, z)
```

Required array shapes for each grid type:

- Rectilinear grid: `x`, `y`, `z` are 1D arrays with different lengths in general.
- Structured grid: `x`, `y`, `z` are 3D arrays with the same shape.

### Add some data to the file

The function `vtk_point_data` adds point data to the file (note: cell data is
not supported for now).
The required input is a VTK file object created by `vtk_grid`, an array and a
string:

```julia
vtk_point_data(vtkfile, p, "Pressure")
vtk_point_data(vtkfile, C, "Concentration")
vtk_point_data(vtkfile, vel, "Velocity")
```

The array can represent either scalar or vectorial data.
In the latter case, the shape of the array should be `[3, Ni, Nj, Nk]`.

### Save the file

Finally, close and save the file with `vtk_save`:

```julia
final_filename = vtk_save(vtkfile)
```

### Multiblock files

Multiblock files (.vtm) are XML VTK files that can point to multiple other VTK
files.
They can be useful when working with complex geometries that are composed of
multiple subdomains.
In order to generate multiblock files, the `vtk_multiblock` function must be used.
The previously introduced functions are then used with some small modifications.

First, a multiblock file must be initialised:

```julia
vtmfile = vtk_multiblock("my_vtm_file")
```

Then, multiple grids can be generated with `vtk_grid` using the `vtmfile`
object as the first argument:

```julia
# First dataset file.
vtkfile = vtk_grid(vtmfile, x1, y1, z1)
vtk_point_data(vtkfile, p1, "Pressure")

# Second dataset file.
vtkfile = vtk_grid(vtmfile, x2, y2, z2)
vtk_point_data(vtkfile, p2, "Pressure")
```

Finally, only the multiblock file needs to be saved explicitely:

```julia
final_filename = vtk_save(vtmfile)
```

## Examples

See some examples in the `test/` directory.
