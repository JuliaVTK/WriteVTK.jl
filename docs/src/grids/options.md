# Additional options

By default, numerical data is written to the XML files as compressed raw binary
data.
This can be changed using the optional keyword arguments of [`vtk_grid`](@ref).

For instance, to disable both compressing and appending raw data in the case of
unstructured meshes:

``` julia
vtk_grid("my_vtk_file", points, cells; compress = false, append = false, ascii = false)
```

## Supported options

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
