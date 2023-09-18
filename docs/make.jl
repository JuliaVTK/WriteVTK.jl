using VTKBase
using WriteVTK
using Documenter

DocMeta.setdocmeta!(
    VTKBase, :DocTestSetup,
    quote
        using VTKBase
    end;
    recursive = true,
)

DocMeta.setdocmeta!(
    WriteVTK, :DocTestSetup,
    quote
        using VTKBase
        using WriteVTK
        using StaticArrays  # not yet used...
    end;
    recursive = true,
)

# Path to markdown file containing docs for VTKBase.jl
# We copy the file to src/external/
vtkbase_docs_src = joinpath(
    dirname(dirname(pathof(VTKBase))),  # VTKBase directory
    "docs",
    "src",
    "VTKBase.md",
)
isfile(vtkbase_docs_src) || error("file not found: $vtkbase_docs_src")
vtkbase_docs = joinpath("external", "VTKBase.md")
cp(vtkbase_docs_src, joinpath(@__DIR__, "src", vtkbase_docs); force = true)

makedocs(;
    modules = [VTKBase, WriteVTK],
    authors = "Juan Ignacio Polanco <juan-ignacio.polanco@cnrs.fr> and contributors",
    repo = Remotes.GitHub("JuliaVTK", "WriteVTK.jl"),
    sitename = "WriteVTK.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://juliavtk.github.io/WriteVTK.jl",
        assets = [
            "assets/tomate.js",
        ],
        mathengine = KaTeX(),
    ),
    pages = [
        "Home" => "index.md",
        "Grid formats" => [
            "grids/syntax.md",
            "grids/structured.md",
            "grids/unstructured.md",
            "grids/datasets.md",
        ],
        "Metadata formats" => [
            "metadata/multiblock.md",
            "metadata/paraview_collections.md",
            "metadata/parallel.md",
        ],
        "Additional tools" => [
            "tools/surface.md",
            "tools/write_array.md",
            "tools/readvtk.md",
        ],
        "API Reference" => "API.md",
        "VTKBase.jl" => vtkbase_docs,
    ],
)

deploydocs(;
    repo = "github.com/JuliaVTK/WriteVTK.jl.git",
    forcepush = true,
)
