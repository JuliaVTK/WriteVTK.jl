# Parallel files

The parallel file formats do not actually store any data in the file.
Instead, the data is broken into pieces, each of which is stored in a serial file,
and an extra header file is created containing pointers to the corresponding serial files.
The header file extension is the serial extension prepended with a `p`.
For instance, for serial `vtu` files, the corresponding header file extension is `pvtu`.

## Generating a parallel data file

The parallel header file and the corresponding serial files are generated
by a single call to [`pvtk_grid`](@ref).
Its signature is

```julia
pvtk_grid(
    filename, args...;
    part, nparts, ismain = (part == 1), ghost_level = 0, kwargs...,
)
```

which returns a handler representing a parallel VTK file that can be
appended with cell and point data and eventually written to disk with
[`close`](@ref) as usual.
In an MPI job, `close` will cause each rank to write a serial file and just
a single rank (e.g., rank 0) will write the header file.

This signature is valid for **unstructured grids**.
For the case of structured grids, there are small differences detailed [further below](#Parallel-structured-files).

Positional and keyword arguments in `args` and `kwargs` are passed to `vtk_grid`
verbatim.
Note that serial filenames are automatically generated from `filename` and from
the process id `part`.

The following keyword arguments only apply to parallel VTK file formats.

Mandatory ones are:

- `part`: current (1-based) part id (typically MPI rank + 1),
- `nparts`: total number of parts (typically the MPI communicator size).

Optional ones are:

- `ismain`: `true` if the current part id `part` is the main (the only one that will write the header file),
- `ghost_level`: ghost level.

## Parallel structured files

For structured grids, one needs to specify the portion of the grid associated to each process.
This is done via the `extents` keyword argument, which must be an array containing the data ranges along each dimension associated to each process.
For example, for a dataset of global dimensions ``15×12×4`` distributed across 4
processes, this array may look like the following:

```julia
extents = [
    ( 1:10,  1:5, 1:4),  # process 1
    (10:15,  1:5, 1:4),  # process 2
    ( 1:10, 5:12, 1:4),  # process 3
    (10:15, 5:12, 1:4),  # process 4
]
```

In practice, in parallel applications, all processes need to have this
information, and the `extents` argument must be the same for all processes.
Also note that the length of the `extents` array gives the number of processes,
and therefore the `nparts` argument is redundant and not needed for structured
grids.

Finally, note that in the example above the extents for different processes
**overlap** (for instance, the ranges `1:10` and `10:15` overlap at the index
`i = 10`).
This is a requirement of VTK, and without it the full data cannot be visualised
in ParaView.
For MPI applications, this typically means that ghost data need to be exchanged
before writing VTK files.

## Example 1: Unstructured files

This generates two serial files (typically held by two different processes) and
a header file combining them:

```julia
all_data = [
    # Process 1
    (
        points = rand(3, 5),  # 5 points on process 1
        cells = [             # 2 cells  on process 1
            MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
            MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5]),
        ],
    ),

    # Process 2
    (
        points = rand(3, 4),  # 4 points on process 2
        cells = [             # 1 cell   on process 2
            MeshCell(VTKCellTypes.VTK_QUAD, [1, 2, 3, 4]),
        ]
    ),
]

saved_files = Vector{Vector{String}}(undef, 2)  # files saved by each "process"

for part = 1:2
    data = all_data[part]
    saved_files[part] = pvtk_grid(
            "simulation", data.points, data.cells;
            part = part, nparts = 2,
        ) do pvtk
        pvtk["Pressure"] = sum(data.points; dims = 1)
    end
end
```

In this example, `saved_files` lists the files saved by each "process":

```julia
julia> saved_files
2-element Vector{Vector{String}}:
 ["simulation.pvtu", "simulation/simulation_1.vtu"]
 ["simulation/simulation_2.vtu"]
```

Note that the files containing the actual data (in this case `simulation_*.vtu`) are stored in a separate `simulation` directory.

## Example 2: Structured files

This generates 4 serial [image data](@ref Image-data) files (`.vti`) and
a header file (`.pvti`) combining them:

```julia
# Global grid
xs_global = range(0, 2; length = 15)
ys_global = range(-1, 1; length = 12)
zs_global = range(0, 1; length = 4)

extents = [
    ( 1:10,  1:5, 1:4),  # process 1
    (10:15,  1:5, 1:4),  # process 2
    ( 1:10, 5:12, 1:4),  # process 3
    (10:15, 5:12, 1:4),  # process 4
]

saved_files = Vector{Vector{String}}(undef, 4)  # files saved by each "process"

for part = 1:4
    is, js, ks = extents[part]  # local indices
    xs, ys, zs = xs_global[is], ys_global[js], zs_global[ks]  # local grid
    saved_files[part] = pvtk_grid(
            "fields", xs, ys, zs;
            part = part, extents = extents,
        ) do pvtk
        pvtk["Temperature"] = [x + 2y + 3z for x ∈ xs, y ∈ ys, z ∈ zs]
    end
end
```

As in the previous example, `saved_files` lists the files saved by each "process":

```julia
julia> saved_files
4-element Vector{Vector{String}}:
 ["fields.pvti", "fields/fields_1.vti"]
 ["fields/fields_2.vti"]
 ["fields/fields_3.vti"]
 ["fields/fields_4.vti"]
```


## Acknowledgements

Thanks to [Francesc Verdugo](https://www.francescverdugo.com/) and [Alberto
F. Martin](https://research.monash.edu/en/persons/alberto-f-martin) for
the initial parallel file format implementation, and to [Corentin Lothode](https://lmrs.univ-rouen.fr/fr/persopage/corentin-lothode) for the initial work on structured grids.
