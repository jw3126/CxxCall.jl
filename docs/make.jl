using CxxCall
using Documenter

DocMeta.setdocmeta!(CxxCall, :DocTestSetup, :(using CxxCall); recursive=true)

makedocs(;
    modules=[CxxCall],
    authors="Jan Weidner <jw3126@gmail.com> and contributors",
    repo="https://github.com/jw3126/CxxCall.jl/blob/{commit}{path}#{line}",
    sitename="CxxCall.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jw3126.github.io/CxxCall.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jw3126/CxxCall.jl",
    devbranch="main",
)
