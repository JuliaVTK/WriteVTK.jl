# Writing datasets

In VTK files, datasets represent scalar, vector or tensor quantities that one may want to visualise.
These quantities are generally attached to either grid points or cells.

The syntax for writing datasets to a file is as follows:

```julia
vtk_grid("fields", x, y, z) do vtk  # create a grid
    vtk["temperature"] = rand(length(x), length(y), length(z))
end
```

