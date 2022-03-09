using Documenter
using XbrlXML

makedocs(
    modules=[XbrlXML],
    authors="Rob <robfoxsimms@gmail.com> and contributors",
    repo="https://github.com/robfs/XbrlXML.jl/blob/{commit}{path}#{line}",
    sitename = "XbrlXML.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://robfs.github.io/XbrlXML.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Cache" => "cache.md",
        "Instance" => "instance.md",
        "Linkbases" => "linkbases.md",
        "Taxonomy" => "taxonomy.md",
    ],
)

deploydocs(;
    repo="github.com/robfs/XbrlXML.jl",
    devbranch="main",
)
