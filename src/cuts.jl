# helpers for cuts

# add initial fixed cuts
function add_init_cuts(opt::Optimizer)
    for cache in opt.cone_caches
        opt.num_cuts += Cones.add_init_cuts(cache, opt)
    end
    return
end

# add relaxation dual cuts
function add_relax_cuts(opt::Optimizer)
    JuMP.has_duals(opt.relax_model) || return false

    cuts = JuMP.AffExpr[]
    for (ci, cache) in zip(opt.relax_oa_cones, opt.cone_caches)
        append!(cuts, get_dual_cuts(ci, cache, false, opt))
    end
    cuts_added = add_cuts(cuts, opt, false)

    if !cuts_added && opt.verbose
        println("continuous relaxation cuts could not be added")
    end
    return cuts_added
end

# add subproblem dual cuts
function add_subp_cuts(
    opt::Optimizer,
    viol_only::Bool,
    cuts_cache::Union{Nothing, Vector{AE}},
)
    JuMP.has_duals(opt.subp_model) || return false

    cuts = JuMP.AffExpr[]
    for (ci, cache) in zip(opt.subp_oa_cones, opt.cone_caches)
        append!(cuts, get_dual_cuts(ci, cache, true, opt))
    end
    cuts_added = add_cuts(cuts, opt, viol_only)

    if !isnothing(cuts_cache)
        append!(cuts_cache, cuts)
    end

    if !cuts_added && opt.verbose
        println("subproblem cuts could not be added")
    end
    return cuts_added
end

# add separation cuts (only if violated)
function add_sep_cuts(opt::Optimizer)
    s_vals = [get_value(Cones.get_oa_s(cache), opt.lazy_cb) for cache in opt.cone_caches]

    cuts = JuMP.AffExpr[]
    for (s, cache) in zip(s_vals, opt.cone_caches)
        append!(cuts, Cones.get_sep_cuts(s, cache, opt))
    end
    cuts_added = add_cuts(cuts, opt, true)

    if !cuts_added && opt.verbose
        println("separation cuts could not be added")
    end
    return cuts_added
end

# get and rescale relaxation/subproblem dual
function get_dual_cuts(ci::CR, cache::Cache, subp_rescale::Bool, opt::Optimizer)
    z = JuMP.dual(ci)

    z_norm = LinearAlgebra.norm(z, Inf)
    if z_norm < 1e-10
        # discard duals with small norm
        return JuMP.AffExpr[]
    elseif z_norm > 1e12
        @warn("norm of dual is large ($z_norm)")
    end

    if subp_rescale
        subp_status = JuMP.termination_status(opt.subp_model)
        if subp_status in (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE)
            # rescale dual rays
            z .*= inv(z_norm)
        end
    end

    return Cones.get_subp_cuts(z, cache, opt)
end
