# General syntax

The syntax for writing VTK files typically looks like the following:

```julia
saved_files = vtk_grid(filename, points..., [cells]; kws...) do vtk
    # add datasets here...
end
```

- Grid coordinates are passed via one or more `points` arguments, as detailed in [Structured grid formats](@ref) and [Unstructured grid formats](@ref).

- The `cells` argument is only relevant for unstructured grids, as detailed in [Unstructured grid formats](@ref).

- Data may be added to the `vtk` handler at the interior of the do-block.
  See [Writing datasets](@ref) for more details.

- The returned variable `saved_files` is a `Vector{String}` containing the paths of the actual VTK files that were saved after the operation.
  When writing VTK dataset files (e.g. structured or unstructured grids), this contains just a single path, but this changes when one is working with metadata files such as [multiblock](@ref Multiblock-files) or [parallel files](@ref Parallel-files).

Note that the above syntax, which uses Julia's
[do-block syntax](https://docs.julialang.org/en/v1/manual/functions/#Do-Block-Syntax-for-Function-Arguments)
is equivalent to:

```julia
vtk = vtk_grid(filename, points..., [cells]; kws...)
# add datasets here...
saved_files = vtk_save(vtk)
```

## Data formatting options

By default, numerical data is written to the XML files as compressed raw binary
data.
This can be changed using the optional keyword arguments of [`vtk_grid`](@ref).

For instance, to disable both compressing and appending raw data in the case of
unstructured meshes:

``` julia
vtk_grid(filename, points, cells; compress = false, append = false, ascii = false)
```

More generally:

- If `append` is `true` (default), data is written appended at the end of the
  XML file as raw binary data.
  Note that this violates the XML specification, but is allowed by VTK formats.

  Otherwise, if `append` is `false`, data is written inline.
  By default, inline data is written base-64 encoded, but may also be written
  in ASCII format (see below).
  Writing inline data is usually slower than writing raw binary data, and also
  results in larger files, but is valid according to the XML specification.

- If `ascii` is `true`, then appended data is written in ASCII format instead
  of base64-encoded.
  This is not the default.
  This option is ignored if `append` is `true`.

- If `compress` is `true` (default), data is first compressed using the [CodecZlib](https://github.com/JuliaIO/CodecZlib.jl) package.
  Its value may also be a compression level between 1 (fast compression)
  and 9 (best compression).
  This option is ignored when writing inline data in ASCII format.

## Setting the VTK file version

The `vtk_grid` function also allows setting the VTK file version using the optional `vtkversion` keyword argument.
This refers to the version of the VTK XML file format that is to be written, and which appears in the `VTKFile` element of the XML file.
Different versions may be interpreted differently by ParaView.
Note that this is a somewhat **advanced option** that may be used to solve
potential issues.

As a real-life example, say that you want to write an [unstructured
dataset](@ref Unstructured-grid-formats) made of [Lagrange hexahedron](https://www.kitware.com/modeling-arbitrary-order-lagrange-finite-elements-in-the-visualization-toolkit/) cells.
Defining each cell requires defining (1) a set of space coordinates, and (2)
determining the way these coordinates connect to form the cell.
The order of the points in the connectivity arrays must follow the specific
node numbering expected by the VTK libraries.
But the node numbering [can change](https://gitlab.kitware.com/vtk/vtk/-/blob/master/Documentation/release/9.1.md#data) from one VTK version to the other.
So, if one constructs the cells following the latest VTK specification, one
should set the VTK file version to the newest one.
See [this discussion](https://discourse.julialang.org/t/writevtk-node-numbering-for-27-node-lagrange-hexahedron/93698) for more details.

The `vtkversion` option is used as follows:

```julia
vtk_grid(filename, points, [cells]; vtkversion = :default, etc...)
```

The `vtkversion` argument can take the following values:

- `:default` (equivalent to `v1.0`);
- `:latest` (currently equivalent to `v2.2`);
- some other version number of the form `vX.Y`.

VTK file version `1.0` is used by default for backwards compatibility and to
make sure that the generated files can be read by old versions of the VTK
libraries and of ParaView.

