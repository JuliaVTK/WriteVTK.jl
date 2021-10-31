# Structured grid formats

[Structured grids](https://en.wikipedia.org/wiki/Regular_grid) are those in which each grid point (or vertex) can be specified by a set of indices such as `(i, j, k)` in three dimensions.

In general, structured grids in WriteVTK are generated using one of the following syntaxes:

```julia
vtk_grid("filename", x, y, z; kwargs...)
vtk_grid("filename", xyz; kwargs...)
```

Note that, while all examples here are done in three-dimensions, things also work as expected in two dimensions (e.g. by only passing `x` and `y` coordinates to `vtk_grid`).

## Rectilinear grid

In a rectilinear grid, points are aligned with the Cartesian directions.
In this case, grid points may be specified by ``\bm{x}_{ijk} = (x_i, y_j, z_k)``, where ``x_i``, ``y_j`` and ``z_k`` are arbitrary sequences (in increasing order).

In WriteVTK, a rectilinear grid is specified by a set of vectors, one for each Cartesian direction:

```julia
x = [0.0, 0.1, 0.5, 1.3]
y = sort(rand(8))
z = [-cospi(i / 10) for i = 0:10]
```

Then, a rectilinear grid file may be written as:
```julia
vtk_grid("filename", x, y, z) do vtk
    # add datasets...
end
```
which will save the file `filename.vtr`.

## Image data

The "image data" (or **uniform grid**) format is a specific case of a rectilinear grid, in which points are uniformly spaced along each of the Cartesian directions.
In this case, grid points may be specified as
``\bm{x}_{ijk} = (x_i, y_j, z_k)``.
This time, each sequence is constrained to the form ``x_i = δx + (i - 1) Δx``, where ``δx`` is an offset and ``Δx`` is the uniform spacing (this equivalently applies to ``y_j`` and ``z_k``).

In WriteVTK, an image data file is automatically created if all coordinates are given as `AbstractRange` objects.
For instance, this will save a `filename.vti` file:

```julia
x = 0:0.1:1
y = 0:0.2:1
z = range(-1, 1; length = 21)

vtk_grid("filename", x, y, z) do vtk
    # add datasets...
end
```

## Structured grid

In a structured (or **curvilinear**) grid, points do not need to be aligned with the Cartesian directions.
In this case, grid points are specified as ``\bm{x}_{ijk} = (x_{ijk}, y_{ijk}, z_{ijk})``.

In WriteVTK, a three-dimensional curvilinear grid may be constructed by passing a set of 3D arrays `x`, `y` and `z` to `vtk_grid`:

```julia
Ni, Nj, Nk = 6, 8, 11
x = [i / Ni * cospi(3/2 * (j - 1) / (Nj - 1)) for i = 1:Ni, j = 1:Nj, k = 1:Nk]
y = [i / Ni * sinpi(3/2 * (j - 1) / (Nj - 1)) for i = 1:Ni, j = 1:Nj, k = 1:Nk]
z = [(k - 1) / Nk for i = 1:Ni, j = 1:Nj, k = 1:Nk]

vtk_grid("filename", x, y, z) do vtk
    # add datasets...
end
```

This will save a `filename.vts` file.

Alternatively, the following syntax also works (and might actually be more efficient), where `xyz` is a single 4-D array of dimensions `(3, Ni, Nj, Nk)`:

```julia
vtk_grid("filename", xyz) do vtk
    # add datasets...
end
```

Again, note that all of the above works similarly in two dimensions, as one may expect.

## Cells in structured formats

In structured grids, cells are implicitly defined as the "bricks" whose vertices are neighbouring grid points.
In three dimensions, these "bricks" are cuboids or [parallelepipeds](https://en.wikipedia.org/wiki/Parallelepiped) with 8 vertices.
Similarly, in two dimensions, these are rectangles or parallelograms.

This means that, if the grid is composed of ``N_i × N_j × N_k`` points, then the number of cells is ``N_c = (N_i - 1) × (N_j - 1) × (N_k - 1)``.
