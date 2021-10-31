# ParaView collections

A ParaView collection file (extension `.pvd`) represents a time series of VTK
files.
This may be used for visualising simulation results at different time steps, and in particular for creating simulation movies.

A `pvd` file is initialised using [`paraview_collection`](@ref):

``` julia
pvd = paraview_collection("my_pvd_file")
```

By default this overwrites existent `pvd` files.
To append new datasets to an existent `pvd` file, set the `append` option to
`true`:

```julia
pvd = paraview_collection("my_pvd_file"; append = true)
```

VTK files are then added to the `pvd` file with

```julia
pvd[time] = vtk
```

Here, `time` is a real number that represents the current time (or timestep) in
the simulation.

When all the files are added to the `pvd` file, it can be saved using:

``` julia
vtk_save(pvd)
```

## Working example

The following is a full working example using the do-block syntax:

```julia
x, y, z = 0:10, 1:6, 2:0.1:3
times = range(0, 10; step = 0.5)

saved_files = paraview_collection("full_simulation") do pvd
    for (n, time) ∈ enumerate(times)
        vtk_grid("timestep_$n", x, y, z) do vtk
            vtk["Pressure"] = rand(length(x), length(y), length(z))
            pvd[time] = vtk
        end
    end
end
```

In this example, the saved files are:
```julia
julia> saved_files
22-element Vector{String}:
 "full_simulation.pvd"
 "timestep_1.vti"
 "timestep_2.vti"
 "timestep_3.vti"
 "timestep_4.vti"
 "timestep_5.vti"
 "timestep_6.vti"
 "timestep_7.vti"
 ⋮
 "timestep_15.vti"
 "timestep_16.vti"
 "timestep_17.vti"
 "timestep_18.vti"
 "timestep_19.vti"
 "timestep_20.vti"
 "timestep_21.vti"
```

## Acknowledgements

Thanks to [Patrick Belliveau](https://github.com/Pbellive) for the initial
implementation of ParaView collection functionality, and to [Sebastian Pech](https://github.com/sebastianpech) for additional improvements.
