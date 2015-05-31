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

## Contents

- [Installation](#installation)
- [Rectilinear and structured meshes](#usage-rectilinear-and-structured-meshes)
- [Unstructured meshes](#usage-unstructured-meshes)
- [Multiblock files](#multiblock-files)
- [Additional options](#additional-options)
- [Examples](#examples)

## Installation

From the Julia REPL:

```julia
Pkg.clone("git@github.com:jipolanco/WriteVTK.jl.git")
```

Then load the module in Julia with:

```julia
using WriteVTK
```

## Usage: rectilinear and structured meshes

### Define a grid

The function `vtk_grid` initialises the VTK file.
This function requires a filename with no extension, and the grid coordinates.
Depending on the shape of the arrays `x`, `y` and `z`, either a rectilinear or
structured grid is created.

```julia
vtkfile = vtk_grid("my_vtk_file", x, y, z)
```

Required array shapes for each grid type:

- Rectilinear grid: `x`, `y`, `z` are 1-D arrays with different lengths in
  general.
- Structured grid: `x`, `y`, `z` are 3-D arrays with the same shape
  `[Ni, Nj, Nk]`.

Alternatively, in the case of structured grids, the grid points can be defined
from a single 4-D array `xyz`, of dimensions `[3, Ni, Nj, Nk]`:

```julia
vtkfile = vtk_grid("my_vtk_file", xyz)
```

This is actually more efficient than the previous formulation.

### Add some data to the file

The function `vtk_point_data` adds point data to the file.
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
  `[3, num_points]` (can be also flattened or reshaped).

- `cells` is a MeshCell array that contains all the cells of the mesh.
  For example:

  ```julia
  # Supposing that the mesh is made of 5 points:
  cells = [MeshCell(VTKCellType.VTK_TRIANGLE, [1, 4, 2]),
           MeshCell(VTKCellType.VTK_QUAD,     [2, 4, 3, 5])]
  ```

Alternatively, the grid points can be defined from three 1-D arrays `x`, `y`,
`z`, of equal lengths, as in
`vtkfile = vtk_grid("my_vtk_file", x, y, z, cells)`.
This is less efficient though.

Now add some data to the file.
It is possible to add both point data and cell data:

```julia
vtk_point_data(vtkfile, pdata, "my_point_data")
vtk_cell_data(vtkfile, cdata, "my_cell_data")
```

The `pdata` and `cdata` arrays must have sizes consistent with the number of
points and cells in the mesh, respectively.
The arrays can contain scalar and vectorial data (see
[here](#add-some-data-to-the-file)).

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
The functions introduced above are then used with some small modifications.

First, a multiblock file must be initialised:

```julia
vtmfile = vtk_multiblock("my_vtm_file")
```

Then, each subgrid can be generated with `vtk_grid` using the `vtmfile` object
as the first argument:

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

## Additional options

By default, numerical data is written to the XML files as compressed raw binary
data.
This can be changed using the optional `compress` and `append` parameters of
the `vtk_grid` functions.

For instance, to disable both compressing and appending raw data in the case of
unstructured meshes:

```julia
vtkfile = vtk_grid("my_vtk_file", points, cells; compress=false, append=false)
```

- If `append` is `true` (default), data is written appended at the end of the
  XML file as raw binary data.
  Note that this violates the XML specification, although it is allowed by VTK.

  Otherwise, if `append` is `false`, data is written "inline", and base-64
  encoded instead of raw.
  This is usually slower than writing raw binary data, and also results in
  larger files, but is valid according to the XML specification.

- If `compress` is `true` (default), data is first compressed using Zlib.

## Examples

See some examples in the `test/` directory.
