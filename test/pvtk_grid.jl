using Base.Threads: @spawn
using StaticArrays
using WriteVTK
using Test

function pvtk_unstructured(; use_abspath = false,)
    # Suppose that the mesh is made of 5 points:
    cells = [
        MeshCell(VTKCellTypes.VTK_TRIANGLE, [1, 4, 2]),
        MeshCell(VTKCellTypes.VTK_QUAD, [2, 4, 3, 5]),
    ]
    x = [0.95, 0.16, 0.07, 0.21, 0.60]
    y = [0.32, 0.55, 0.87, 0.12, 0.85]
    pvtk_name = "simulation" * (use_abspath ? "_abs" : "")
    pvtk_dir = use_abspath ? abspath(pvtk_name) : pvtk_name
    vtufile = joinpath(pvtk_dir, "$(pvtk_name)_1.vtu")
    rm(vtufile, force = true)
    @time outfiles = pvtk_grid(pvtk_dir, x, y, cells; part = 1, nparts = 1) do pvtk # 2D
        pvtk["Pressure"] = x
        pvtk["Processor"] = [1,2]
        pvtk["Temperature", VTKPointData()] = y
        pvtk["Id", VTKCellData()] = [2, 1]
        pvtk["TimeValue"] = 4.2
    end
    @test isfile(vtufile)
    @test vtufile ∈ outfiles
    @test WriteVTK._serial_filename(3, 100, "prefix", ".ext") == "prefix_003.ext"
    outfiles
end

function pvtk_unstructured_higherorderdegrees()
    cells = [
        MeshCell(VTKCellTypes.VTK_LAGRANGE_QUADRILATERAL, [
            1, 3, 12, 10, 2, 6, 9, 11, 4, 7, 5, 8
        ]),
    ]
    x = [0, 0.5, 1, 0, 0.5, 1, 0, 0.5, 1, 0, 0.5, 1]
    y = [0, 0, 0, 1/3, 1/3, 1/3, 2/3, 2/3, 2/3, 1, 1, 1]
    vtufile = "higherorderdegrees/higherorderdegrees_1.vtu"
    rm(vtufile, force = true)
    outfiles = pvtk_grid("higherorderdegrees", x, y, cells; part = 1, nparts = 1) do pvtk
        pvtk["HigherOrderDegrees", VTKCellData()] = [2;3;12]
        pvtk[VTKCellData()] = Dict("HigherOrderDegrees"=>"HigherOrderDegrees")
        # This is not very useful... it's just for testing the alternative syntax:
        pvtk[VTKPointData()] = "AttributeA" => "A"
        pvtk[VTKFieldData()] = ("AttributeX" => "X", "AttributeY" => "Y")
    end
    @test isfile(vtufile)
    @test vtufile ∈ outfiles
    outfiles
end

function make_structured_partition()
    Ns = (10, 15, 3)
    xp = (1:5, 5:10)  # NOTE: overlapping is required by VTK
    yp = (1:3, 3:12, 12:15)
    zp = (1:3, )
    extents = collect(Iterators.product(xp, yp, zp))
    Ns, extents
end

function pvtk_imagedata()
    Ns, extents = make_structured_partition()
    xs_whole = map(N -> range(-1.0; step = 0.2, length = N), Ns)  # full grid
    nparts = length(extents)  # number of "processes"
    filenames = Vector{Vector{String}}(undef, nparts)
    @sync for (n, extent) ∈ enumerate(extents)
        @spawn begin
            xs = getindex.(xs_whole, extent)  # local grid
            point_data = map(sum, Iterators.product(xs...))
            processid = fill(n, length.(xs) .- 1)  # cell data
            filenames[n] = pvtk_grid(
                "pimage", xs...;
                part = n, extents = extents,
                append = false, compress = false,
            ) do vtk
                vtk["point_data"] = point_data
                vtk["process_id"] = processid
                vtk["TimeValue"] = 1.2
            end
        end
    end
    collect(Iterators.flatten(filenames))
end

function pvtk_rectilinear()
    Ns, extents = make_structured_partition()
    nparts = length(extents)  # number of "processes"
    filenames = Vector{Vector{String}}(undef, nparts)
    @sync for (n, extent) ∈ enumerate(extents)
        @spawn begin
            xs = map(is -> [sqrt(i) for i ∈ is], extent)  # local grid
            point_data = map(sum, Iterators.product(xs...))
            vecdata = (1, 2, 3) .* Ref(point_data)
            processid = fill(n, length.(xs) .- 1)  # cell data
            filenames[n] = pvtk_grid(
                "prectilinear", xs...;
                part = n, extents = extents,
                append = false, compress = false,
            ) do vtk
                vtk["point_data"] = point_data
                vtk["vector", component_names = ("Ux", "Uy", "Uz")] = vecdata
                vtk["process_id"] = processid
                vtk["TimeValue"] = 3.4
            end
        end
    end
    collect(Iterators.flatten(filenames))
end

# In this test we write to a subdirectory using relative paths.
function pvtk_structured()
    Ns, extents = make_structured_partition()
    nparts = length(extents)  # number of "processes"
    filenames = Vector{Vector{String}}(undef, nparts)
    outdir = "pvtk_structured_output"
    mkpath(outdir)
    outname = joinpath(outdir, "pstructured")
    @sync for (n, extent) ∈ enumerate(extents)
        @spawn begin
            points = [
                SVector(
                    I[1] + sqrt(I[2]),
                    I[2] + sqrt(I[1]),
                    I[3] + sqrt(I[1] + I[2]),
                )
                for I ∈ CartesianIndices(extent)
            ]
            point_data = map(sum, points)
            processid = fill(n, length.(extent) .- 1)  # cell data
            filenames[n] = pvtk_grid(
                outname, points;
                part = n, extents = extents,
                append = false, compress = false,
            ) do vtk
                vtk["point_data"] = point_data
                vtk["process_id"] = processid
                vtk["TimeValue"] = 3.5
            end
        end
    end
    collect(Iterators.flatten(filenames))
end

function main()
    vcat(
        pvtk_unstructured(use_abspath = false),
        pvtk_unstructured(use_abspath = true),
        pvtk_unstructured_higherorderdegrees(),
        pvtk_imagedata(),
        pvtk_rectilinear(),
        pvtk_structured(),
    )
end

main()
