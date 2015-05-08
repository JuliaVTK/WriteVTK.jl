# WriteVTK

[![Build Status](https://travis-ci.org/jipolanco/WriteVTK.jl.svg?branch=master)](https://travis-ci.org/jipolanco/WriteVTK.jl)

This module allows to write VTK XML files, that can be visualised for example
with [ParaView](http://www.paraview.org/).

The data is written compressed by default, using the
[Zlib](https://github.com/dcjones/Zlib.jl) package.

Rectilinear (.vtr), structured (.vts) and unstructured (.vtu) grids are
supported.
Multiblock files (.vtm), which can point to multiple VTK files, can also be
exported.

## Installation

From the Julia REPL:

```julia
Pkg.clone("git@github.com:jipolanco/WriteVTK.jl.git")
```

## Usage: rectilinear and structured meshes

### Create a grid

The function `vtk_grid` initialises the VTK file.
This function requires a filename with no extension, and the grid coordinates.
Depending on the shape of the arrays `x`, `y` and `z`, either a rectilinear or
structured grid is created.

```julia
using WriteVTK

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
outfiles = vtk_save(vtkfile)
```

`outfiles` is an array of strings with the paths to the generated files.
In this case, the array is obviously of length 1, but that changes when working
with multiblock files.

## Usage: unstructured meshes

An unstructured mesh is defined by a set of points in space and a set of cells
that connect those points.

### Defining cells

In WriteVTK, a cell is defined using the MeshCell type:

```julia
cell = MeshCell(cell_type, connectivity)
```

- `cell_type` is an integer value that determines the type of the cell, as
  defined in the
  [VTK specification](http://www.vtk.org/VTK/img/file-formats.pdf).
  For convenience, WriteVTK includes a `VTKCellType` module that contains these
  definitions.
  For instance, a triangle is associated to the value
  `cell_type = VTKCellType.VTK_TRIANGLE`.

- `connectivity` is a vector of indices that determine the mesh points that are
  connected by the cell.
  In the case of a triangle, this would be an integer array of length 3.

  Note that the indices are one-based (as opposed to
  [zero-based](https://en.wikipedia.org/wiki/Zero-based_numbering)),
  following the convention in Julia.

### Generating an unstructured VTK file

First, initialise the file:

```julia
vtkfile = vtk_grid("my_vtk_file", points, cells)
```

- `points` is an array with the point locations, of dimensions
  `[3, num_points]` (possibly flattened).

- `cells` is a MeshCell array that contains all the cells of the mesh.
  For example:

  ```julia
  # Supposing that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellType.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellType.VTK_QUAD,     [2, 4, 3, 5])]
  ```

Now add some data to the file.
It is possible to add both point data and cell data:

```julia
vtk_point_data(vtkfile, pdata, "my_point_data")
vtk_cell_data(vtkfile, cdata, "my_cell_data")
```

The `pdata` and `cdata` arrays must have sizes consistent with the number of
points and cells respectively.
Just like in the structured case, the arrays can contain scalar and vectorial data.

Finally, close the file:

```julia
outfiles = vtk_save(vtkfile)
```

## Multiblock files

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
# First block.
vtkfile = vtk_grid(vtmfile, x1, y1, z1)
vtk_point_data(vtkfile, p1, "Pressure")

# Second block.
vtkfile = vtk_grid(vtmfile, x2, y2, z2)
vtk_point_data(vtkfile, p2, "Pressure")
```

Finally, only the multiblock file needs to be saved explicitely:

```julia
outfiles = vtk_save(vtmfile)
```

Assuming that the two blocks are structured grids, this generates the files
`my_vtm_file.vtm`, `my_vtm_file.z01.vts` and `my_vtm_file.z02.vts`, where the
`vtm` file points to the two `vts` files.

## Examples

See some examples in the `test/` directory.
