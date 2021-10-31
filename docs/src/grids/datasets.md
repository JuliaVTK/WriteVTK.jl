# Writing datasets

In VTK files, datasets represent scalar, vector or tensor quantities that one may want to visualise.
These quantities are generally attached to either grid points or cells.

The simplest syntax for writing datasets to a file is as follows:

```julia
x, y, z = 0:10, 1:6, 2:0.1:3
Nx, Ny, Nz = length(x), length(y), length(z)

vtk_grid("fields", x, y, z) do vtk
    vtk["Temperature"] = rand(Nx, Ny, Nz)              # scalar field attached to points
    vtk["Pressure"] = rand(Nx - 1, Ny - 1, Nz - 1)     # scalar field attached to cells
    vtk["Velocity"] = rand(3, Nx, Ny, Nz)              # vector field attached to points
    vtk["VelocityGradients"] = rand(3, 3, Nx, Ny, Nz)  # 3×3 tensor field attached to points
    vtk["date"] = "31/10/2021"                         # metadata ("field data" in VTK)
    vtk["time"] = 0.42                                 # metadata ("field data" in VTK)
end
```

In the above example, WriteVTK automatically decides whether data is to be
attached to grid points or to grid cells depending on the dimensions of the
input.
In particular, note that the `Pressure` field is attached to cells instead of points, since it has dimensions ``(N_x - 1) × (N_y - 1) × (N_z - 1)``, which is the number of cells in structured files (see [Cells in structured formats](@ref)).
For more control, see [Dataset types](@ref) below.

## Passing tuples of arrays

Note that, in the example above, the `Velocity` vector field is passed as a single ``3 × N_x × N_y × N_z`` array, which is the layout ultimately used in VTK formats.
In some applications, one may instead prefer to work with vector fields as a collection of separate scalar fields, or similarly as an array of dimensions ``N_x × N_y × N_z × 3``.

To avoid unnecessary allocations in transposing the data to ``3 × N_x × N_y × N_z`` format, WriteVTK also allows passing vector and tensor fields as tuples of arrays.
For example:

```julia
x, y, z = 0:10, 1:6, 2:0.1:3
Nx, Ny, Nz = length(x), length(y), length(z)
vx, vy, vz = rand(Nx, Ny, Nz), rand(Nx, Ny, Nz), rand(Nx, Ny, Nz)  # vector as separate fields
ω = rand(Nx, Ny, Nz, 3)
∇v = rand(Nx, Ny, Nz, 3, 3)

vtk_grid("fields_tuples", x, y, z) do vtk
    # Pass vectors as tuples of scalars
    vtk["Velocity"] = (vx, vy, vz)
    vtk["Vorticity"] = @views (ω[:, :, :, 1], ω[:, :, :, 2], ω[:, :, :, 3])

    # Similarly for tensors
    vtk["VelocityGradients"] = @views (
        ∇v[:, :, :, 1, 1], ∇v[:, :, :, 2, 1], ∇v[:, :, :, 3, 1],
        ∇v[:, :, :, 1, 2], ∇v[:, :, :, 2, 2], ∇v[:, :, :, 3, 2],
        ∇v[:, :, :, 1, 3], ∇v[:, :, :, 2, 3], ∇v[:, :, :, 3, 3],
    )
end
```

## Passing arrays of static arrays

Alternatively, a common use case is to store vector fields as arrays of
static arrays, using the
[StaticArrays](https://github.com/JuliaArrays/StaticArrays.jl) package.
This use case is naturally supported by WriteVTK:

```julia
using StaticArrays

x, y, z = 0:10, 1:6, 2:0.1:3
Nx, Ny, Nz = length(x), length(y), length(z)
v = rand(SVector{3, Float64}, Nx, Ny, Nz)
∇v = rand(SMatrix{3, 3, Float32, 9}, Nx, Ny, Nz)

vtk_grid("fields_sarray", x, y, z) do vtk
    vtk["Velocity"] = v
    vtk["VelocityGradients"] = ∇v
end
```

One may also specify grid coordinates using arrays of static arrays:

```julia
using StaticArrays

Nx, Ny, Nz = 5, 6, 10
xs = [SVector(sqrt(i) + 2j + 3k, 2i - j + k, -i + 3j - k)
      for i = 1:Nx, j = 1:Ny, k = 1:Nz]

vtk_grid("coords_sarray", xs) do vtk
    # add datasets here...
end
```

!!! note "(Lack of) dependencies"

    Note that the WriteVTK package does not directly depend on StaticArrays, as
    there is no StaticArrays-specific implementation allowing for the
    functionality described in this section.
    Instead, the implementation is quite generic, and the above may also work with array types that behave similarly to StaticArrays.

## Dataset types

The syntax exposed above is high-level, in the sense that WriteVTK
automatically decides on the type of dataset depending on the dimensions of the
input data.

The VTK format defines three different kinds of dataset:

- [`VTKPointData`](@ref) for data attached to grid points,
- [`VTKCellData`](@ref) for data attached to grid cells,
- [`VTKFieldData`](@ref) for everything else.
  This may be used to store lightweight metadata, such as time information or
  strings.

For more control, one can explicitly pass an instance of `VTKPointData`,
`VTKCellData` and `VTKFieldData` when adding a dataset to a VTK file.

For example:

```julia
x, y, z = 0:10, 1:6, 2:0.1:3
Nx, Ny, Nz = length(x), length(y), length(z)

vtk_grid("fields_explicit", x, y, z) do vtk
    vtk["Temperature", VTKPointData()] = rand(Nx, Ny, Nz)
    vtk["Pressure", VTKCellData()] = rand(Nx - 1, Ny - 1, Nz - 1)
    vtk["Velocity", VTKPointData()] = rand(3, Nx, Ny, Nz)
    vtk["VelocityGradients", VTKPointData()] = rand(3, 3, Nx, Ny, Nz)
    vtk["date", VTKFieldData()] = "31/10/2021"
    vtk["time", VTKFieldData()] = 0.42
end
```
