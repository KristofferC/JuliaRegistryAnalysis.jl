# JuliaRegistryAnalysis

WIP of tools to analyze the registry

Run this before examples:

```julia
using JuliaRegistryAnalysis
using Graphs, MetaGraphs
# Hint: Look at docstring for JuliaRegistryAnalysis.dependency_graph
graph = JuliaRegistryAnalysis.dependency_graph()
name_to_vertex = Dict{String, Int}(get_prop(graph, i, :label) => i for i in 1:nv(graph))
```


## Examples
### Output the dependency graph of a given package

```julia
plots_subgraph = egonet(graph, name_to_vertex["Plots"], typemax(Int))
open("PlotsDepGraph.dot", "w") do io
    MetaGraphs.savedot(io, plots_subgraph)
end
```

Visualized with Gephi:

![drawing](https://i.imgur.com/NsIjrDE.png)


### Sort a list of packages according to popularity (number of direct dependencies)

```julia
# Sorting
packages = ["Distributions", "Compat", "Crayons", "DataFrames", "OhMyREPL", "Plots", "CUDA", "NearestNeighbors"]
sort(packages; by=x-> Graphs.indegree(graph, name_to_vertex[x]))
```

Result:
```julia
8-element Vector{String}:
 "OhMyREPL"
 "Crayons"
 "NearestNeighbors"
 "CUDA"
 "Compat"
 "Plots"
 "DataFrames"
 "Distributions"
 ```
