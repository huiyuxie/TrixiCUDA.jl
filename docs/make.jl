# TrixiCUDA.jl is not accessible through Julia's LOAD_PATH currently
push!(LOAD_PATH, "../src/")

using Documenter
using TrixiCUDA

DocMeta.setdocmeta!(TrixiCUDA, :DocTestSetup, :(using TrixiCUDA); recursive = true)

makedocs(sitename = "TrixiCUDA.jl",
         pages = [
             "Home" => "index.md",
             "Tutorial 1" => "aws_gpu_setup.md",
             "Tutorial 2" => "nsys_profiling.md"
         ],
         format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"))

deploydocs(repo = "github.com/trixi-gpu/TrixiCUDA.jl",
           devbranch = "main",
           push_preview = true)
