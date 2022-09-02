using WriteVTK
using Documenter

DocMeta.setdocmeta!(
    WriteVTK, :DocTestSetup,
    quote
        using WriteVTK
        using StaticArrays  # not yet used...
    end;
    recursive = true,
)

makedocs(;
    modules = [WriteVTK],
    authors = "Juan Ignacio Polanco <jipolanc@gmail.com> and contributors",
    repo = "https://github.com/jipolanco/WriteVTK.jl/blob/{commit}{path}#L{line}",
    sitename = "WriteVTK.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://jipolanco.github.io/WriteVTK.jl",
        assets = [
            "assets/tomate.js",
        ],
        mathengine = KaTeX(),
    ),
    pages=[
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
    ],
)

deploydocs(;
    repo = "github.com/jipolanco/WriteVTK.jl.git",
    forcepush = true,
)
