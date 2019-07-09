using Documenter
using WriteVTK

makedocs(
    sitename = "WriteVTK",
    format = Documenter.HTML(),
    modules = [WriteVTK]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
