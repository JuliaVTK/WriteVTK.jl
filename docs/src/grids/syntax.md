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

## Supported options

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
