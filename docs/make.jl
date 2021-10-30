using WriteVTK
using Documenter

DocMeta.setdocmeta!(
    WriteVTK, :DocTestSetup, :(using WriteVTK);
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
        assets = String[],
        mathengine = KaTeX(),
    ),
    pages=[
        "Home" => "index.md",
        "Grid formats" => [
            "grids/structured.md",
            "grids/unstructured.md",
            "grids/options.md",
        ],
        "Writing datasets" => [
        ],
        "Metadata formats" => [
        ],
        "API Reference" => "API.md",
    ],
)

deploydocs(;
    repo = "github.com/jipolanco/WriteVTK.jl.git",
    forcepush = true,
)
