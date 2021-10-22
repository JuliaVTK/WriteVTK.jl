# WriteVTK

[![Build Status](https://github.com/jipolanco/WriteVTK.jl/workflows/CI/badge.svg)](https://github.com/jipolanco/WriteVTK.jl/actions)
[![Coverage](https://codecov.io/gh/jipolanco/WriteVTK.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jipolanco/WriteVTK.jl)
[![DOI](https://zenodo.org/badge/32700186.svg)](https://zenodo.org/badge/latestdoi/32700186)

This package allows to write VTK XML files for visualisation of multidimensional
datasets using tools such as [ParaView](http://www.paraview.org/).

The supported VTK file formats include rectilinear (.vtr) and structured grids
(.vts), image data (.vti), unstructured grids (.vtu) and polygonal data (.vtp).
Multiblock files (.vtm), which can point to multiple VTK files, can also be
exported; as well as ParaView collection files (.pvd), which can be used to
visualise time series of VTK files.

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Rectilinear and structured meshes](#rectilinear-and-structured-meshes)
- [Image data](#image-data)
- [Unstructured meshes](#unstructured-meshes)
- [Polygonal data](#polygonal-data)
- [Visualising Julia arrays](#visualising-julia-arrays)
- [Multiblock files](#multiblock-files)
- [Paraview PVD files](#paraview-data-pvd-file-format)
- [Parallel file formats](#parallel-file-formats)
- [Do-block syntax](#do-block-syntax)
- [Additional options](#additional-options)
- [Examples](#examples)

## Installation

From the Julia REPL:

```julia
]add WriteVTK
```

Then load the package in Julia with:

```julia
using WriteVTK
```

## Quick start

The `vtk_grid` function is the entry point for creating different kinds of VTK
files.
In the simplest cases, one just passes coordinate information to this function.
WriteVTK then decides on the VTK format that is more adapted for the provided
data.

For instance, it is natural in Julia to describe a 3D uniform grid, with
regularly spaced increments, as a list of ranges:

```julia
x = 0:0.1:1
y = 0:0.2:1
z = -1:0.05:1
```

This specific way of specifying coordinates is compatible with the *image data*
VTK format (.vti files).
The following creates such a file, with some scalar data attached to each point:

```julia
vtk_grid("my_dataset", x, y, z) do vtk
    vtk["my_point_data"] = rand(length(x), length(y), length(z))
end
```

This will save a `my_dataset.vti` file with the data.
Note that the file extension should not be included in the filename, as it will
be attached automatically according to the dataset type.

By changing the coordinate specifications, the above can be naturally
generalised to non-uniform grid spacings and to curvilinear and unstructured
grids.
In each case, the correct kind of VTK file will be generated.

## Rectilinear and structured meshes

### Define a grid

The function `vtk_grid` initialises the VTK file.
This function requires a filename with no extension, and the grid coordinates.
Depending on the shape of the arrays `x`, `y` and `z`, either a rectilinear or
structured grid is created.

``` julia
vtkfile = vtk_grid("my_vtk_file", x, y, z) # 3-D
vtkfile = vtk_grid("my_vtk_file", x, y)    # 2-D
```

Required array shapes for each grid type:

- Rectilinear grid: `x`, `y`, `z` are 1-D arrays with different lengths in
  general (`Ni`, `Nj` and `Nk` respectively).
- Structured grid: `x`, `y`, `z` are 3-D arrays with the same
  shape: `(Ni, Nj, Nk)`. For the two dimensional case, `x` and `y` are 2-D arrays
  with shape `(Ni, Nj)`

Alternatively, in the case of structured grids, the grid points can be defined from a
single 4-D array `xyz`, of dimensions `(3, Ni, Nj, Nk)`. For the two dimensional case
`xy` is a 3-D array, with dimensions `(2, Ni, Nj)`:

``` julia
vtkfile = vtk_grid("my_vtk_file", xyz) # 3-D
vtkfile = vtk_grid("my_vtk_file", xy)  # 2-D
```

This is actually more efficient than the previous formulation.

### Add some data to the file

In a VTK file, data can be associated to grid points or to data cells
(see [Defining cells](#defining-cells) for details on cells).
Data is written to a VTK file object using the syntax

```julia
vtkfile["Velocity"] = vel
vtkfile["Pressure"] = p
vtkfile["Concentration"] = C
```

where the "index" is the name of the dataset in the VTK file.

It is also possible to write datasets whose dimensions are independent of the
discrete geometry.
In VTK this is called "field data", and can be used to write metadata such as
time information or strings:

```julia
vtkfile["Time"] = 42.0
vtkfile["Date"] = "30/05/2020"
vtkfile["Distances"] = [2.0, 4.0, 8.0]
```

For convenience, the input data is automatically associated either to grid
points or data cells, or interpreted as field data, according to the input data
dimensions.
If more control is desired, one can explicitly pass a `VTKPointData`,
a `VTKCellData` or a `VTKFieldData` instance as a second index:

```julia
vtkfile["Velocity", VTKPointData()] = vel
vtkfile["Pressure", VTKCellData()] = p
vtkfile["Time", VTKFieldData()] = 42.0
```

Note that in rectilinear and structured meshes, the cell dimensions are
always `(Ni - 1, Nj - 1, Nk - 1)`, and the dimensions of the data arrays associated to cells should be consistent with these dimensions.

The input array can represent either scalar or vectorial data.
The shape of the array should be `(Ni, Nj, Nk)` for scalars, and
`(Nc, Ni, Nj, Nk)` for vectors, where `Nc` is the number of components of
the vector.

Vector datasets can also be given as a tuple of scalar datasets, where each
scalar represents a component of the vector field.
Example:

```julia
acc = (acc_x, acc_y, acc_z)  # acc_x, acc_y and acc_z have size (Ni, Nj, Nk)
vtkfile["Acceleration"] = acc
```

This can be useful to avoid copies of data in some cases.

### Save the file

Finally, close and save the file with `vtk_save`:

``` julia
outfiles = vtk_save(vtkfile)
```

`outfiles` is an array of strings with the paths to the generated files.
In this case, the array is of length 1, but that changes when working
with [multiblock files](#multiblock-files).

## Image data

The points and cells of an image data file are defined by the number of points
in each direction, `(Nx, Ny, Nz)`.
In addition, the origin of the dataset and the spacing in each direction can be
optionally specified.
Example:

``` julia
Nx, Ny, Nz = 10, 12, 42
origin = (3.0, 4.0, -3.2)
spacing = (0.1, 0.2, 0.3)
vtk = vtk_grid("my_vti_file", Nx, Ny, Nz, origin=origin, spacing=spacing)
vtk_save(vtk)
```

Coordinates may also be specified using ranges (any subtype of `AbstractRange`
works).
Some examples:

```julia
# Using StepRangeLen objects
vtk_grid("vti_file_1", 0:0.1:10, 0:0.2:10, 1:0.3:4)

# Using LinRange objects
vtk_grid("vti_file_2", LinRange(0, 4.2, 10), LinRange(1, 3.1, 42), LinRange(0.2, 12.1, 32))
```

## Unstructured meshes

An unstructured mesh is defined by a set of points in space and a set of cells
that connect those points.

### Defining cells

In WriteVTK, a cell is defined using the MeshCell type:

``` julia
cell = MeshCell(cell_type, connectivity)
```

- `cell_type` is of type `VTKCellType` which contains the name and an integer value that
  determines the type of the cell, as defined in the
  [VTK specification](http://www.vtk.org/VTK/img/file-formats.pdf) (see figures 2 and 3 in
  that document). For convenience, WriteVTK includes a `VTKCellTypes` module that contains
  these definitions. For instance, a triangle is associated to the value `cell_type = VTKCellTypes.VTK_TRIANGLE`.
  Cell types may also be constructed from their associated integer identifier.
  For instance, `VTKCellType(5)` also returns a `VTK_TRIANGLE` cell type.

- `connectivity` is a vector of indices that determine the mesh points that are connected
  by the cell. In the case of a triangle, this would be an integer array of length 3.

  Note that the connectivity indices are one-based (as opposed to
  [zero-based](https://en.wikipedia.org/wiki/Zero-based_numbering)), following the
  convention in Julia.

### Generating an unstructured VTK file

First, initialise the file:

``` julia
vtkfile = vtk_grid("my_vtk_file", points, cells)
```

- `points` is an array with the point locations, of dimensions `(dim, num_points)` where
  `dim` is the dimension (1, 2 or 3) and `num_points` the number of points.

- `cells` is a MeshCell array that contains all the cells of the mesh. For example:

    ```julia
    # Suppose that the mesh is made of 5 points:
    cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
             MeshCell(VTKCellTypes.VTK_QUAD,     [2, 4, 3, 5])]
    ```

Alternatively, the grid points can be defined from 1-D arrays `x`, `y`,
`z` with equal lengths `num_points`:

``` julia
vtkfile = vtk_grid("my_vtk_file", x, y, z, cells) # 3D
vtkfile = vtk_grid("my_vtk_file", x, y, cells)    # 2D
vtkfile = vtk_grid("my_vtk_file", x, cells)       # 1D
```

or from a 4-D array `points`, with dimension `[dim, Ni, Nj, Nk]` where `dim` is the dimension
and `Ni`,`Nj`,`Nk` the number of points in each direction `x`,`y`,`z`:

``` julia
vtkfile = vtk_grid("my_vtk_file", points, cells)
```

These two last methods are less efficient though.

Now add some data to the file.
It is possible to add both point data and cell data:

``` julia
vtkfile["my_point_data", VTKPointData()] = pdata
vtkfile["my_cell_data", VTKCellData()] = cdata
```

The `pdata` and `cdata` arrays must have sizes consistent with the number of
points and cells in the mesh, respectively.
Note that, as discussed [above](#add-some-data-to-the-file), the second
argument (`VTKPointData()` or `VTKCellData()`) can be generally omitted.
In this case, its value will be automatically determined from the input data
dimensions.

Finally, close and save the file:

``` julia
outfiles = vtk_save(vtkfile)
```

## Polyhedron cells

WriteVTK also supports the creation of unstructured VTK files containing [polyhedron cells](https://vtk.org/Wiki/VTK/Polyhedron_Support).
The specificity of polyhedron cells is that they require the specification not only of a connectivity vector, but also of a list of faces constituting the polyhedron.
To specify a polyhedron cell, instead of using the `MeshCell` type, one should create an instance of `VTKPolyhedron`.

The following simple example creates a cube as a polyhedron cell (see also `test/polyhedron_cube.jl` for an example with two cubes):

```julia
# Vertices of the cube
points = permutedims(Float32[
    -1 -1 -1;
     1 -1 -1;
     1  1 -1;
    -1  1 -1;
    -1 -1  1;
     1 -1  1;
     1  1  1;
    -1  1  1;
])

# Create a single polyhedron cell describing the cube
cells = [
    VTKPolyhedron(
        1:8,           # connectivity vector
        (1, 4, 3, 2),  # face 1
        (1, 5, 8, 4),  # face 2
        (5, 6, 7, 8),  # etc...
        (6, 2, 3, 7),
        (1, 2, 6, 5),
        (3, 4, 8, 7),
    ),
]

# Finally, create a simple VTK file
vtk_grid("polyhedron_cube", points, cells; compress = false) do vtk
    # one can add point and cell data here...
end
```

## Polygonal data

Polygonal datasets are a special type of unstructured grids, in which the cell
types are restricted to vertices, lines, triangle strips and polygons.
In WriteVTK, these shapes are respectively identified by the singleton types
`PolyData.Verts`, `PolyData.Lines`, `PolyData.Strips` and `PolyData.Polys`.

The specification of points is the same as for unstructured grids.
Cells are specified by passing one of the above types to `MeshCell`.
For instance, the following specifies a line passing by 4 points of the grid:

```julia
line = MeshCell(PolyData.Lines(), [3, 4, 7, 2])
```

Similarly to unstructured grids, a VTK file is created by passing vectors of
cells to `vtk_grid`.
The difference is that one can pass multiple vectors (one for each cell type),
and that each vector may only contain a single cell type.

Example:

```julia
# Create lists of lines and polygons connecting different points in space
points = rand(3, 100)  # (x, y, z) locations
lines = [MeshCell(PolyData.Lines(), (i, i + 1, i + 4)) for i in (3, 5, 42)]
polys = [MeshCell(PolyData.Polys(), i:(i + 6)) for i = 1:3:20]
vtk = vtk_grid("my_vtp_file", points, lines, polys)
```

Note that the order of `lines` and `polys` is not important.
More generally, one can pass any combination of the four polygonal primitives
mentioned above.

Once the grid is created, point and cell data can be added to the file just like
for unstructured grids.

⚠️ **Known issue**: when the polygonal dataset contains multiple kinds of cells
(e.g. both lines and polygons), cell data is not correctly parsed by the VTK
libraries, and as a result it cannot be visualised in ParaView.
The problem doesn't happen with point data.
This seems to be a [very old](https://vtk.org/pipermail/vtkusers/2004-August/026448.html) [VTK issue](https://gitlab.kitware.com/vtk/vtk/-/issues/564).

## Visualising Julia arrays

A convenience function is provided to quickly save Julia arrays as image data:

```julia
A = rand(100, 100, 100)
vtk_write_array("my_vti_file", A, "my_property_name")
```

## Multiblock files

Multiblock files (.vtm) are XML VTK files that can point to multiple other VTK
files.
They can be useful when working with complex geometries that are composed of
multiple sub-domains.
In order to generate multiblock files, the `vtk_multiblock` function must be used.
The functions introduced above are then used with some small modifications.

First, a multiblock file must be initialised:

``` julia
vtmfile = vtk_multiblock("my_vtm_file")
```

Then, each sub-grid can be generated with `vtk_grid` using the `vtmfile` object
as the first argument:

``` julia
# First block.
vtkfile = vtk_grid(vtmfile, x1, y1, z1)
vtkfile["Pressure"] = p1

# Second block.
vtkfile = vtk_grid(vtmfile, x2, y2, z2)
vtkfile["Pressure"] = p2
```

Additional blocks can also be added to the multiblock file with
`multiblock_add_block`, which can contain any of the VTK files that WriteVTK
supports:

```julia
# Create a block named my_multiblock and add it to vtmfile.
block = multiblock_add_block(vtmfile, "my_multiblock")

# Add a VTK file to `block`.
vtkfile = vtk_grid(block, "another_file", x3, y3, z3)
```

Blocks can be nested arbitrarily:

```julia
# Add more blocks.
another_block = multiblock_add_block(block, "my_multiblock-block")
yet_another_block = multiblock_add_block(another_block, "my_multiblock-block-block")
```

And more VTK files may be added to the sub-blocks:

```julia
vtkfile = vtk_grid(yet_another_block, "my_deeply_nested_file", x4, y4, z4)
```

Finally, only the multiblock file needs to be saved explicitly:

``` julia
outfiles = vtk_save(vtmfile)
```

WriteVTK will write out a multiblock VTK file that looks like something like this (in addition to all the VTK files contained in the multiblock file):

```xml
<?xml version="1.0" encoding="utf-8"?>
<VTKFile type="vtkMultiBlockDataSet" version="1.0" byte_order="LittleEndian">
  <vtkMultiBlockDataSet>
    <DataSet index="0" file="my_vtm_file_1.vti"/>
    <DataSet index="1" file="my_vtm_file_2.vti"/>
    <Block index="2" name="my_multiblock">
      <DataSet index="0" file="another_file.vti" name="another_file"/>
      <Block index="1" name="my_multiblock-block">
        <Block index="0" name="my_multiblock-block-block">
          <DataSet index="0" file="my_deeply_nested_file.vti" name="my_deeply_nested_file"/>
        </Block>
      </Block>
    </Block>
  </vtkMultiBlockDataSet>
</VTKFile>
```

## Paraview Data (PVD) file format

A `pvd` file is a collection of VTK files, typically for holding results at
different time steps in a simulation. A `pvd` file is initialised with:

``` julia
pvd = paraview_collection("my_pvd_file")
```

By default this overwrites existent `pvd` files.
To append new datasets to an existent `pvd` file, set the `append` option to
`true`:

```julia
pvd = paraview_collection("my_pvd_file", append=true)
```

VTK files are then added to the `pvd` file with

```julia
pvd[time] = vtkfile
```

Here, `time` is a real number that represents the current time (or timestep) in
the simulation.

When all the files are added to the `pvd` file, it can be saved using:

``` julia
vtk_save(pvd)
```

## Parallel file formats

The parallel file formats do not actually store any data in the file.
Instead, the data is broken into pieces, each of which is stored in a serial file,
and an extra header file is created containing pointers to the corresponding serial files.
The header file extension is the serial extension pre-appended with a `p`.
For instance, for serial `vtu` files, the corresponding header file extension is `pvtu`.

### Generating a parallel data file

The parallel header file and the corresponding serial files are generated
using the `pvtk_grid` function. Its signature is

```julia
pvtk_grid(
    args...;
    part,
    nparts,
    ismain = (part == 1),
    ghost_level = 0,
    kwargs...,
)
```
which returns a handler representing a parallel VTK file that can be
appended with cell and point data and eventually written to disk with
`vtk_save` as usual. In an MPI job, `vtk_save` will cause each rank
to write a serial file and just a single rank (e.g., rank 0) will write the header file.

Positional and keyword arguments in `args` and `kwargs`
are passed to `vtk_grid` verbatim in order to generate the serial files
(with the exception of file names that are augmented with the
corresponding part id).

The extra keyword arguments only apply to parallel VTK file formats.

Mandatory ones are:

- `part` current (1-based) part id (typically MPI rank + 1),
- `nparts` total number of parts (typically the MPI communicator size).

Optional ones are:

- `ismain` true if the current part id `part` is the main (the only one that will write the header file),
- `ghost_level` ghost level.

⚠️ **Remark:** Only tested for unstructured grid format (`vtu`).

### Example

This generates the header file and a single serial file
```julia
cells = [
  MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
  MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5]),
]
x = rand(5)
y = rand(5)

pvtk = pvtk_grid("simulation", x, y, cells; part = 1, nparts = 1)
pvtk["Pressure"] = x
pvtk["Processor"] = rand(2)
outfiles = vtk_save(pvtk)
```

## Do-block syntax

[Do-block syntax](https://docs.julialang.org/en/v1/manual/functions/#Do-Block-Syntax-for-Function-Arguments)
is supported by `vtk_grid`, `pvtk_grid`, `vtk_multiblock` and `paraview_collection`.
At the end of the do-block, `vtk_save` is called implicitly on the generated
VTK object.
Example:

``` julia
# Image data, rectilinear or structured grid
outfiles = vtk_grid("my_vtk_file", x, y, z) do vtk
    vtk["Pressure"] = p
    vtk["Velocity"] = vel
end

# Multiblock file
outfiles = vtk_multiblock("my_vtm_file") do vtm
    vtk = vtk_grid(vtm, x1, y1, z1)
    vtk["Velocity"] = vel1

    vtk = vtk_grid(vtm, x2, y2, z2)
    vtk["Velocity"] = vel2
end
```

## Additional options

By default, numerical data is written to the XML files as compressed raw binary
data.
This can be changed using the optional keyword arguments of `vtk_grid`.

For instance, to disable both compressing and appending raw data in the case of
unstructured meshes:

``` julia
vtk = vtk_grid("my_vtk_file", points, cells; compress = false, append = false, ascii = false)
```

- If `append` is `true` (default), data is written appended at the end of the
  XML file as raw binary data.
  Note that this violates the XML specification, although it is allowed by VTK.

  Otherwise, if `append` is `false`, data is written inline. By default,
  inline data is written base-64 encoded, but may also be written in ASCII
  format (see below).
  Writing inline data is usually slower than writing raw binary data, and also
  results in larger files, but is valid according to the XML specification.

- If `ascii` is `true`, then appended data is written in ASCII format instead
  of base64-encoded. This is not the default. This option is ignored if
  `append` is `true`.

- If `compress` is `true` (default), data is first compressed using zlib.
  Its value may also be a compression level between 1 (fast compression)
  and 9 (best compression). This option is ignored when writing inline data in
  ASCII format.

## Examples

See some examples in the `test/` directory.
