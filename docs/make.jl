using WGPUgfx
using Documenter

DocMeta.setdocmeta!(WGPUgfx, :DocTestSetup, :(using WGPUgfx); recursive=true)

makedocs(;
    modules=[WGPUgfx],
    authors="arhik <arhik23@gmail.com>",
    repo="https://github.com/JuliaWGPU/WGPUgfx.jl/blob/{commit}{path}#{line}",
    sitename="WGPUgfx.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://arhik.github.io/WGPUgfx.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaWGPU/WGPUgfx.jl",
    devbranch="main",
)
