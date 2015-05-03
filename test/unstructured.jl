#!/usr/bin/env julia

# Create unstructured grid VTK file.

# TODO
# - Test more complex meshes.
# - Find another way to define the cell types?
# - Add some cell and point data.

using WriteVTK
typealias FloatType Float32
const vtk_filename_noext = "unstructured"

function main()
    # For now, we work on a really simple case.
    const Npts = 5
    pts = Array(FloatType, 3, Npts)
    pts[:, 1] = [0, 0, 0]
    pts[:, 2] = [1, 0, 0]
    pts[:, 3] = [1, 1, 0]
    pts[:, 4] = [2, 2, 0]
    pts[:, 5] = [4, 1, 0]

    # Define cells.
    cells = MeshCell[]
    push!(cells, MeshCell(WriteVTK.VTK_TRIANGLE, [1, 2, 3]))
    push!(cells, MeshCell(WriteVTK.VTK_QUAD,     [2, 3, 4, 5]))

    # Initialise new vtu file (unstructured grid).
    @time vtk = vtk_grid(vtk_filename_noext, pts, cells)

    # TODO add cell and point data

    # Save and close vtk file.
    outfiles = vtk_save(vtk)
    println("Saved:   ", outfiles...)

    return outfiles::Vector{UTF8String}
end

main()
