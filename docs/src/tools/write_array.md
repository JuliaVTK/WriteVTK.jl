# Visualising Julia arrays

A convenience function, [`vtk_write_array`](@ref), is provided to quickly save Julia arrays as image data:

```julia
p = rand(100, 100, 100)
vtk_write_array("filename", p, "Pressure")
```

This may be useful for visualising the data contained in a Julia array.

## Writing multiple arrays

Multiple arrays can be given as a tuple.
For instance,

    vtk_write_array("filename", (u, v), ("u", "v"))

In that case, the arrays must have the same dimensions.

## Acknowledgements

Thanks to [Júlio Hoffimann](https://juliohm.github.io/) for adding this functionality.
