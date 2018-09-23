#!/usr/bin/env julia

# Create unstructured grid VTK file.

using WriteVTK

const FloatType = Float32
const vtk_filename_noext = "unstructured"

# 3D mesh
function mesh_data(::Val{3})
    # This is basically a structured grid, but defined as an unstructured one.
    # Based on the structured.jl example.
    Ni, Nj, Nk = 40, 50, 20
    indices = LinearIndices((1:Ni, 1:Nj, 1:Nk))
    Npts = length(indices)

    # Create points and point data.
    pts_ijk = Array{FloatType}(undef, 3, Ni, Nj, Nk)
    pdata_ijk = Array{FloatType}(undef, Ni, Nj, Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts_ijk[1, i, j, k] = r * cos(th)
        pts_ijk[2, i, j, k] = r * sin(th)
        pts_ijk[3, i, j, k] = (k - 1)/(Nk - 1)
        pdata_ijk[i, j, k] = i*i + k*sqrt(j)
    end

    # Create cells (all hexahedrons in this case) and cell data.
    celltype = VTKCellTypes.VTK_HEXAHEDRON
    cells = MeshCell[]
    cdata = FloatType[]

    for k = 2:Nk, j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = Array{Int32}(undef, 8)
        inds[1] = indices[i-1, j-1, k-1]
        inds[2] = indices[i  , j-1, k-1]
        inds[3] = indices[i  , j  , k-1]
        inds[4] = indices[i-1, j  , k-1]
        inds[5] = indices[i-1, j-1, k  ]
        inds[6] = indices[i  , j-1, k  ]
        inds[7] = indices[i  , j  , k  ]
        inds[8] = indices[i-1, j  , k  ]

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j*k)
    end

    pts = reshape(pts_ijk, 3, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

# 2D mesh
function mesh_data(::Val{2})
    Ni, Nj = 40, 50
    indices = LinearIndices((1:Ni, 1:Nj))
    Npts = length(indices)

    # Create points and point data.
    pts_ijk = Array{FloatType}(undef, 2, Ni, Nj)
    pdata_ijk = Array{FloatType}(undef, Ni, Nj)

    for j = 1:Nj, i = 1:Ni
        r = 1 + (i - 1)/(Ni - 1)
        th = 3*pi/4 * (j - 1)/(Nj - 1)
        pts_ijk[1, i, j] = r * cos(th)
        pts_ijk[2, i, j] = r * sin(th)
        pdata_ijk[i, j] = i*i + sqrt(j)
    end

    # Create cells (all quads in this case) and cell data.
    celltype = VTKCellTypes.VTK_QUAD
    cells = MeshCell[]
    cdata = FloatType[]

    for j = 2:Nj, i = 2:Ni
        # Define connectivity of cell.
        inds = Array{Int32}(undef, 4)
        inds[1] = indices[i-1, j-1]
        inds[2] = indices[i  , j-1]
        inds[3] = indices[i  , j  ]
        inds[4] = indices[i-1, j  ]

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i*j)
    end

    pts = reshape(pts_ijk, 2, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

# 1D mesh
function mesh_data(::Val{1})
    Ni = 40
    Npts = Ni

    # Create points and point data.
    pts_ijk = Array{FloatType}(undef, 1, Ni)
    pdata_ijk = Array{FloatType}(undef, Ni)

    for i = 1:Ni
        pts_ijk[1, i] = (i-1)^2 / (Ni-1)^2
        pdata_ijk[i] = i*i
    end

    # Create cells (all lines in this case) and cell data.
    celltype = VTKCellTypes.VTK_LINE
    cells = MeshCell[]
    cdata = FloatType[]

    for i = 2:Ni
        # Define connectivity of cell.
        inds = Array{Int32}(undef, 2)
        inds[1] = i-1
        inds[2] = i

        # Define cell.
        c = MeshCell(celltype, inds)

        push!(cells, c)
        push!(cdata, i)
    end

    pts = reshape(pts_ijk, 1, Npts)
    pdata = reshape(pdata_ijk, Npts)

    return pts, cells, pdata, cdata
end

function main()
    outfiles = String[]
    for dim in 1:3
        pts, cells, pdata, cdata = mesh_data(Val{dim}())

        @time begin
            # Initialise new vtu file (unstructured grid).
            vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", pts, cells,
                           compress=3)

            # This is also accepted in 3D:
            # vtk = vtk_grid(vtk_filename_noext, pts[1, :], pts[2, :], pts[3, :],
            #                cells)

            # Add some point and cell data.
            vtk_point_data(vtk, pdata, "my_point_data")
            vtk_cell_data(vtk, cdata, "my_cell_data")

            # Save and close vtk file.
            append!(outfiles, vtk_save(vtk))
        end
    end

    println("Saved:  ", join(outfiles, "  "))
    return outfiles::Vector{String}
end

main()
