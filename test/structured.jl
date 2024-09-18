# Create structured grid VTK file.

using WriteVTK
using StaticArrays: SVector

const FloatType = Float32
const vtk_filename_noext = "structured"

abstract type GridFormat end
name(g::GridFormat) = nameof(typeof(g))

struct MultipleVectors <: GridFormat end
struct SingleArray <: GridFormat end
struct VectorOfSVector <: GridFormat end

function generate_structured(grid_format, ::Val{dim}) where {dim}
    # Define grid.
    if dim === 2
        Ni, Nj, Nk = 20, 30, 1
    elseif dim === 3
        Ni, Nj, Nk = 20, 30, 40
    end

    if dim === 2
        xyz = zeros(FloatType, 2, Ni, Nj)
        for j = 1:Nj, i = 1:Ni
            xyz[1, i, j] = i/Ni * cos(3*pi/2 * (j-1) / (Nj-1))
            xyz[2, i, j] = i/Ni * sin(3*pi/2 * (j-1) / (Nj-1))
        end
    elseif dim === 3
        xyz = zeros(FloatType, 3, Ni, Nj, Nk)
        for k = 1:Nk, j = 1:Nj, i = 1:Ni
            xyz[1, i, j, k] = i/Ni * cos(3*pi/2 * (j-1) / (Nj-1))
            xyz[2, i, j, k] = i/Ni * sin(3*pi/2 * (j-1) / (Nj-1))
            xyz[3, i, j, k] = (k-1) / Nk
        end
    end

    # Create some scalar and vectorial data.
    q = zeros(FloatType, Ni, Nj, Nk)
    vec = zeros(FloatType, 3, Ni, Nj, Nk)
    vs = zeros(SVector{3, FloatType}, Ni, Nj, Nk)  # equivalent to `vec`

    # Just to test support for subarrays:
    p = zeros(FloatType, 2Ni, 2Nj, 2Nk)
    psub = view(p, 1:Ni, 1:Nj, 1:Nk)

    for k = 1:Nk, j = 1:Nj, i = 1:Ni
        p[i, j, k] = i*i + k
        q[i, j, k] = k*sqrt(j)
        vec[1, i, j, k] = i
        vec[2, i, j, k] = j
        vec[3, i, j, k] = k
        vs[i, j, k] = (i, j, k)
    end

    # Create some scalar data at grid cells.
    # Note that in structured grids, the cells are the hexahedra (3D) or quads (2D)
    # formed between grid points.
    if dim === 2
        cdata = zeros(FloatType, Ni-1, Nj-1)
        for j = 1:Nj-1, i = 1:Ni-1
            cdata[i, j] = 2i + 20 * sin(3*pi * (j-1) / (Nj-2))
        end
    elseif dim === 3
        cdata = zeros(FloatType, Ni-1, Nj-1, Nk-1)
        for k = 1:Nk-1, j = 1:Nj-1, i = 1:Ni-1
            cdata[i, j, k] = 2i + 3k * sin(3*pi * (j-1) / (Nj-2))
        end
    end

    # We test defining grid points using different formats.
    points = if grid_format === SingleArray()
        xyz
    elseif grid_format === MultipleVectors()
        if dim === 3
            x = xyz[1, :, :, :]
            y = xyz[2, :, :, :]
            z = xyz[3, :, :, :]
            (x, y, z)
        else
            x = reshape(xyz[1, :, :, :], Ni, Nj)
            y = reshape(xyz[2, :, :, :], Ni, Nj)
            (x, y)
        end
    elseif grid_format === VectorOfSVector()
        map(Iterators.product(ntuple(d -> axes(xyz, d + 1), Val(dim))...)) do inds
            vals = ntuple(i -> i ≤ dim ? xyz[i, inds...] : zero(eltype(xyz)), 3)
            SVector(vals...)
        end
    end

    @time begin
        # Initialise new vts file (structured grid).
        fname = "$(vtk_filename_noext)_$(dim)D_$(name(grid_format))"
        vtk = vtk_grid(fname, points)

        # Add data.
        vtk["p_values"] = psub
        vtk["q_values"] = q
        vtk["myVector"] = vec
        vtk["myCellData"] = cdata

        # Test writing vector data as tuple of scalar arrays.
        @views vec_tuple = (vec[1, :, :, :],
                            vec[2, :, :, :],
                            vec[3, :, :, :])
        vtk["myVector.tuple"] = vec_tuple

        # Test writing vector data as array of SVector's.
        vtk["myVector.SVector"] = vs

        # Save and close vtk file.
        close(vtk)
        @test isopen(vtk) == false
    end
end

function main()
    outfiles = String[]

    for dim in 2:3, fmt in (MultipleVectors(), SingleArray(), VectorOfSVector())
        fnames = generate_structured(fmt, Val(dim))
        append!(outfiles, fnames)
    end

    println("Saved:  ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()
