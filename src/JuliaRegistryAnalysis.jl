module JuliaRegistryAnalysis

import MetaGraphs, Graphs
import Pkg
using Pkg.Registry: compat_info, registry_info, reachable_registries, RegistryInstance, JULIA_UUID, weak_compat_info
using Pkg.Types: stdlibs
using UUIDs
using TOML

is_stdlib(uuid::UUID) = uuid in keys(stdlibs())
is_jll(name::AbstractString) = endswith(name, "_jll")

function get_name(reg, uuid)
    name_version = get(stdlibs(), uuid, nothing)
    if name_version === nothing
        return reg[uuid].name
    else
        name, version = name_version
        return name
    end
end

"""
    dependency_graph(; include::(name::String, uuid::UUID) -> Bool`)
    
Return the dependency graph as a 
By default, `include` is defined as `(name, uuuid) -> !(is_stdlib(uuid) || is_jll(name))`
which means that it will not include stdlibs or JLLs.

The graph is a `MetaGraphs.MetaDiGraph` with the following properties on the vertices:
- `:label`: The name of the package
- `:uuid`: The uuid of the package

The recommended way of saving the graph to a file is using `MetaGraphs.savedot(io, graph)`
"""
function dependency_graph(; include::Function = (name, uuid) -> !(is_stdlib(uuid) || is_jll(name)), include_weak_deps::Bool=false)
     # TODO, limit registries
    regs = reachable_registries()
    
    d = Dict{UUID, Int}()
    n_vertices = 0

    # Registries
    for reg in regs
        for uuid in keys(reg)
            is_stdlib(uuid) && continue
            name = get_name(reg, uuid)
            include_package(name, uuid; include) || continue
            n_vertices += 1
            haskey(d, uuid) || (d[uuid] = n_vertices)
        end
    end

    # Stdlibs
    for (uuid, (name, version)) in stdlibs()
        include_package(name, uuid; include) || continue
        n_vertices += 1
        haskey(d, uuid) || (d[uuid] = n_vertices)
    end
    
    g = MetaGraphs.MetaDiGraph(Graphs.SimpleGraphs.SimpleDiGraph(n_vertices))

    # Stdlib dependencies
    for (uuid, (name, version)) in stdlibs()
        include_package(name, uuid; include) || continue
        props = Dict(:label => name, :name => name, :uuid => uuid)
        MetaGraphs.set_props!(g, d[uuid], props)
        # Add edges
        proj = joinpath(Sys.STDLIB, name, "Project.toml")
        proj_toml = TOML.parsefile(proj)
        for (_, dep_uuid) in get(Dict, proj_toml, "deps")
            dep_uuid = UUID(dep_uuid)
            dep_name = get_name(nothing, dep_uuid)
            include_package(dep_name, dep_uuid; include) || continue
            Graphs.add_edge!(g, d[uuid], d[dep_uuid])
        end
    end

    # Registry dependencies
    for reg in regs
        for (uuid, entry) in reg
            is_stdlib(uuid) && continue
            pkg = registry_info(entry)
            name = get_name(reg, uuid)
            include_package(name, uuid; include) || continue
            props = Dict(:label => name, :name => name, :uuid => uuid) # add registry as a property?
            MetaGraphs.set_props!(g, d[uuid], props)

            # Regular dependencies
            cinfo = compat_info(pkg)
            # Only consider last version
            max_v = maximum(keys(cinfo))
            cinfo_max_v = cinfo[max_v]
            weak_cinfo = weak_compat_info(pkg)
            weak_cinfo_max_v = nothing
            if weak_cinfo !== nothing
                weak_cinfo_max_v = get(weak_cinfo, max_v, nothing)
            end
            for (dep_uuid, _) in cinfo_max_v
                dep_name = get_name(reg, dep_uuid)
                if weak_cinfo_max_v !== nothing && dep_uuid in keys(weak_cinfo_max_v)
                    continue
                end
                include_package(dep_name, dep_uuid; include) || continue
                Graphs.add_edge!(g, d[uuid], d[dep_uuid])
                MetaGraphs.set_prop!(g, Graphs.Edge(d[uuid], d[dep_uuid]), :weak, false)
            end

            # Weak dependencies
            if include_weak_deps
                weak_cinfo === nothing && continue
                # Only consider last version
                weak_cinfo_max_v === nothing && continue
                for (dep_uuid, _) in weak_cinfo_max_v
                    dep_name = get_name(reg, dep_uuid)
                    include_package(dep_name, dep_uuid; include) || continue
                    Graphs.add_edge!(g, d[uuid], d[dep_uuid])
                    MetaGraphs.set_prop!(g, Graphs.Edge(d[uuid], d[dep_uuid]), :weak, true)
                end
            end
        end
    end
    Graphs.is_cyclic(g) && @warn("Dependency graph contains cycles")
    return g
end

function include_package(name, uuid; include::Function)
    uuid == JULIA_UUID && return false
    return include(name, uuid)::Bool
end

end # module JuliaRegistryAnalysis
