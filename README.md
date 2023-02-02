# JuliaRegistryAnalysis

WIP of tools to analyze the registry

Run this before examples:

```julia
using JuliaRegistryAnalysis
using Graphs, MetaGraphs
# Hint: Look at docstring for JuliaRegistryAnalysis.dependency_graph
include_weak_deps = true
graph = JuliaRegistryAnalysis.dependency_graph(; include_weak_deps)
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
sort(packages; by=x->Graphs.indegree(graph, name_to_vertex[x]))
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

#### Version that considers transitive dependencies

```julia
trans = transitiveclosure(graph.graph)
sort(packages; by=x->Graphs.indegree(trans, name_to_vertex[x]))
```

Result:

```julia
8-element Vector{String}:
 "OhMyREPL"
 "Plots"
 "CUDA"
 "NearestNeighbors"
 "DataFrames"
 "Crayons"
 "Distributions"
 "Compat"
```

### Find all packages directly depending on another package.

```julia
graph_rev = reverse(graph)
requires_deps_verts = neighborhood(graph_rev, name_to_vertex["Requires"], 1)[2:end]
requires_deps_verts_sorted = sort(requires_deps; by=x->Graphs.indegree(graph, x))
requires_deps = [get_prop(graph, i, :label) => Graphs.indegree(graph, i) for i in requires_deps_verts_sorted]
```

Result:

```julia
440-element Vector{Pair{String, Int64}}:
                   "DeconvOptim" => 0
                      "ThArrays" => 0
              "FinancialToolbox" => 0
           "ServiceSolicitation" => 0
                         "Finch" => 0
                       "FMIFlux" => 0
 "MotionCaptureJointCalibration" => 0
               "SignalOperators" => 0
                  "PressureDrop" => 0
                  "PlanetOrbits" => 0
                  "FreezeCurves" => 0
                                 ⋮
                     "Symbolics" => 65
                        "Revise" => 66
             "CategoricalArrays" => 87
                    "DiffEqBase" => 100
                        "Zygote" => 107
                          "HDF5" => 139
                          "CUDA" => 159
                "Interpolations" => 203
                         "Plots" => 233
                        "FileIO" => 251
```
