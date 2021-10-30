# Unstructured grid formats

[Unstructured grids](https://en.wikipedia.org/wiki/Unstructured_grid) are those in which each grid point (or vertex) can be arbitrarily placed in space.
Such points are generally connected to define cells of different shapes.

In general, unstructured grids require the specification of grid points, and of the cells that define the mesh.
A cell is specified by a shape (tetrahedron, triangle, ...) and by a list of grid points (the *connectivity* vector) that define the cell.
In WriteVTK, a cell is described by a [`MeshCell`](@ref) object.

An unstructured grid is then defined by passing a list of grid coordinates and of cells to [`vtk_grid`](@ref), as in

```julia
vtk_grid("filename", points, cells)
```

As detailed in the next sections, depending on the actual kind of `MeshCell`s contained in `cells`, either an [unstructured grid](@ref Unstructured-grid) (`.vtu`) or a [polydata grid](@ref Polydata-grid) (`.vtp`) file is written.

Above, `points` is an array with the point locations, of dimensions `(dim, num_points)` where `dim` is the spatial dimension (1, 2 or 3) and `num_points` the number of points.
Alternatively, grid points may be specified by passing separate 1D vectors of length `num_points`, as in

```julia
vtk_grid("filename", x, y, z, cells)
```

## Defining cells

A single cell is created as

``` julia
cell = MeshCell(cell_type, connectivity)
```

Here, `cell_type` defines the cell shape, while `connectivity` is a list of grid point indices determining the cell location.
Note that the connectivity indices are one-based (as opposed to
[zero-based](https://en.wikipedia.org/wiki/Zero-based_numbering)), following the
convention in Julia.

For example, the following creates a triangular cell:

```julia
cell = MeshCell(VTKCellTypes.VTK_TRIANGLE, (1, 2, 4))
```

Note that, since this is a triangle, the connectivity vector *must* contain three elements (corresponding to the three vertices of the triangle), and an error is thrown if that is not the case.

## Unstructured grid

The cell types available for the unstructured grid format are those listed in the
[VTK specification](http://www.vtk.org/VTK/img/file-formats.pdf) (figures 2 and 3).
For convenience, WriteVTK includes a [`VTKCellTypes`](@ref) module that contains
these definitions.
For instance, a triangle is associated to the cell type `VTKCellTypes.VTK_TRIANGLE`.

The following example creates a `filename.vtu` file with two cells:

```julia
points = rand(3, 5)  # 5 points in three dimensions
cells = [MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
         MeshCell(VTKCellTypes.VTK_QUAD,     [2, 4, 3, 5])]

vtk_grid("filename", points, cells) do vtk
    # add datasets...
end
```


## Polydata grid

This is a specific type of unstructured grid that is restricted to a small subset of cell types, namely vertices, lines, triangle strips and polygons.
In WriteVTK, these shapes are respectively identified by the singleton types
`PolyData.Verts`, `PolyData.Lines`, `PolyData.Strips` and `PolyData.Polys` (see also the [`PolyData`](@ref) module).

Polydata cells are specified by passing one of the above types to `MeshCell`.
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

vtk_grid("my_vtp_file", points, lines, polys) do vtk
    # add datasets...
end
```

!!! warning "Known issue"

    When the polygonal dataset contains multiple kinds of cells
    (e.g. both lines and polygons), cell data is not correctly parsed by the VTK
    libraries, and as a result it cannot be visualised in ParaView.
    The problem doesn't happen with point data.
    This seems to be a [very old](https://vtk.org/pipermail/vtkusers/2004-August/026448.html) [VTK issue](https://gitlab.kitware.com/vtk/vtk/-/issues/564).


## Polyhedron cells

WriteVTK also supports the creation of unstructured VTK files containing [polyhedron cells](https://vtk.org/Wiki/VTK/Polyhedron_Support).
The specificity of polyhedron cells is that they require the specification not only of a connectivity vector, but also of a list of faces constituting the polyhedron.
To specify a polyhedron cell, instead of using the [`MeshCell`](@ref) type, one should create an instance of [`VTKPolyhedron`](@ref).

The following simple example creates a cube as a polyhedron cell (see also [`test/polyhedron_cube.jl`](https://github.com/jipolanco/WriteVTK.jl/blob/master/test/polyhedron_cube.jl) for an example with two cubes):

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
vtk_grid("polyhedron_cube", points, cells) do vtk
    # add datasets...
end
```

