# Create rectilinear grid VTK file.

using WriteVTK
using StaticArrays: SVector, SMatrix

using Test

const FloatType = Float32
const vtk_filename_noext = "rectilinear"

function main()
    outfiles = String[]
    for dim in 2:3
        # Define grid.
        if dim == 2
            Ni, Nj, Nk = 20, 30, 1
        elseif dim == 3
            Ni, Nj, Nk = 20, 30, 40
        end

        x = zeros(FloatType, Ni)
        y = zeros(FloatType, Nj)
        z = zeros(FloatType, Nk)

        [x[i] = i*i/Ni/Ni for i = 1:Ni]
        [y[j] = sqrt(j/Nj) for j = 1:Nj]
        [z[k] = k/Nk for k = 1:Nk]

        # Create some scalar and vector data.
        p = zeros(FloatType, Ni, Nj, Nk)
        q = zeros(FloatType, Ni, Nj, Nk)
        vec = zeros(FloatType, 3, Ni, Nj, Nk)
        vs = zeros(SVector{3, FloatType}, Ni, Nj, Nk)  # this is an alternative way of specifying a vector dataset

        # 3×3 tensors
        tensor = zeros(FloatType, 3, 3, Ni, Nj, Nk)
        ts = zeros(SMatrix{3, 3, FloatType, 9}, Ni, Nj, Nk)

        for k = 1:Nk, j = 1:Nj, i = 1:Ni
            p[i, j, k] = i*i + k
            q[i, j, k] = k*sqrt(j)

            vec[1, i, j, k] = i
            vec[2, i, j, k] = j
            vec[3, i, j, k] = k
            vs[i, j, k] = (i, j, k)

            A = similar(eltype(ts))
            c = i - 2j + 3k
            for I ∈ CartesianIndices(A)
                v = (10 + I[1] - I[2]) * c
                A[I] = v
                tensor[I, i, j, k] = v
            end
            ts[i, j, k] = A
        end

        # Create some scalar data at grid cells.
        # Note that in structured grids, the cells are the hexahedra (3D) or quads (2D)
        # formed between grid points.
        local cdata
        if dim == 2
            cdata = zeros(FloatType, Ni-1, Nj-1)
            for j = 1:Nj-1, i = 1:Ni-1
                cdata[i, j] = 2i + 20 * sin(3*pi * (j-1) / (Nj-2))
            end
        elseif dim == 3
            cdata = zeros(FloatType, Ni-1, Nj-1, Nk-1)
            for k = 1:Nk-1, j = 1:Nj-1, i = 1:Ni-1
                cdata[i, j, k] = 2i + 3k * sin(3*pi * (j-1) / (Nj-2))
            end
        end

        # Test extents (this is optional!!)
        ext = map(N -> (1:N) .+ 42, (Ni, Nj, Nk))

        # Initialise new vtr file (rectilinear grid).
        @time begin
            local vtk
            if dim == 2
                vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", x, y; extent=ext)
            elseif dim == 3
                vtk = vtk_grid(vtk_filename_noext*"_$(dim)D", x, y, z; extent=ext)
            end

            # Add data.
            vtk["p_values"] = p
            vtk["q_values"] = q

            # Test passing the second optional argument.
            @test_throws DimensionMismatch WriteVTK.num_components(
                vec, vtk, VTKCellData())
            vtk["myVector", VTKPointData()] = vec
            vtk["mySVector", VTKPointData()] = vs

            vtk["tensor"] = tensor
            vtk["tensor.SMatrix"] = ts

            vtk["myCellData"] = cdata

            # Save and close vtk file.
            append!(outfiles, close(vtk))
            @test isopen(vtk) == false
        end

    end # dim loop

    println("Saved:  ", join(outfiles, "  "))
    return outfiles::Vector{String}
end

main()
