# Parallel files

The parallel file formats do not actually store any data in the file.
Instead, the data is broken into pieces, each of which is stored in a serial file,
and an extra header file is created containing pointers to the corresponding serial files.
The header file extension is the serial extension pre-appended with a `p`.
For instance, for serial `vtu` files, the corresponding header file extension is `pvtu`.

!!! note "Supported dataset types"

    For now, parallel file formats have only been tested for [unstructured grid](@ref Unstructured-grid) formats (`.vtu`), and are currently unlikely to work for other kinds of datasets.
    Feel free to open an issue or to submit a PR to add support for other dataset types.

## Generating a parallel data file

The parallel header file and the corresponding serial files are generated
using the [`pvtk_grid`](@ref) function.
Its signature is

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
[`vtk_save`](@ref) as usual.
In an MPI job, `vtk_save` will cause each rank to write a serial file and just
a single rank (e.g., rank 0) will write the header file.

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

## Example

This generates the header file and a single serial file:

```julia
cells = [
    MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
    MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5]),
]

x = rand(5)
y = rand(5)

saved_files = pvtk_grid("simulation", x, y, cells; part = 1, nparts = 1) do pvtk
    pvtk["Pressure"] = x
    pvtk["Processor"] = rand(2)
end
```

In this example, `saved_files` lists the two files saved at the end of the do-block:

```julia
julia> saved_files
2-element Vector{String}:
 "simulation.pvtu"
 "simulation/simulation_1.vtu"
```

Note that the files containing the actual data (in this case `simulation_1.vtu`) are stored in a separate `simulation` directory.

## Acknowledgements

Thanks to [Francesc Verdugo](https://www.francescverdugo.com/) and [Alberto
F. Martin](https://research.monash.edu/en/persons/alberto-f-martin) for
the initial parallel file format implementation.
