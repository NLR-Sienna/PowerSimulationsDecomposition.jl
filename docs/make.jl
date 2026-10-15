using Documenter
using PowerSimulationsDecomposition

makedocs(;
    modules=[PowerSimulationsDecomposition],
    format=Documenter.HTML(;
        prettyurls=haskey(ENV, "GITHUB_ACTIONS"),
        edit_link=nothing,
        assets=[
            asset("https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"),
            "assets/mermaid.js",
            "assets/diagrams.css",
        ],
    ),
    sitename="PowerSimulationsDecomposition.jl",
    authors="PowerSimulationsDecomposition.jl contributors",
    strict=true,
    checkdocs=:exports,
    pages=[
        "Overview" => "index.md",
        "Getting started" => "quick_start_guide.md",
        "Tutorials" => ["Two-region dispatch" => "tutorials/intro_page.md"],
        "How-to guides" => [
            "Assign subsystems" => "how_to/subsystems.md",
            "Read results" => "how_to/results.md",
        ],
        "Explanations" => [
            "Split-area modeling" => "explanation/decomposition.md",
            "State passing" => "explanation/state_passing.md",
        ],
        "Formulation library" =>
            ["Network and state-estimation flows" => "formulation_library/network.md"],
        "Reference" => [
            "Public API" => "api/public.md",
            "Support and limitations" => "api/support.md",
            "Internal extensions" => "api/internal.md",
        ],
        "Developers" => [
            "Repository map" => "developer/index.md",
            "Extension lifecycle" => "developer/architecture.md",
            "Workflow and validation" => "developer/workflow.md",
            "Style guide" => "developer/style.md",
        ],
    ],
)

if get(ENV, "DOCS_DEPLOY", "false") == "true"
    deploydocs(;
        repo="github.com/NLR-Sienna/PowerSimulationsDecomposition.jl.git",
        target="build",
        branch="gh-pages",
        devbranch="main",
        devurl="dev",
        push_preview=false,
        versions=["stable" => "v^", "v#.#"],
    )
end
