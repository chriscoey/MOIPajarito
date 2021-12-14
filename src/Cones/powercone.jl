#=
power cone, parametrized by exponent t ∈ (0, 1)
(u, v, w) : u ≥ 0, v ≥ 0, u^t * v^(1-t) ≥ |w|
equivalently (v > 0, u ≥ v * |w / v|^(1/t))
dual cone
(p, q, r) : p ≥ 0, q ≥ 0, (p/t)^t * (q/(1-t))^(1-t) ≥ |r|
equivalently (q > 0, p ≥ t / (1-t) * q * |(1-t) * r / q|^(1/t))
=#

mutable struct PowerConeCache <: ConeCache
    cone::MOI.PowerCone
    t::Real
    s_oa::Vector{VR}
    s::Vector{Float64}
    PowerConeCache() = new()
end

function create_cache(s_oa::Vector{VR}, cone::MOI.PowerCone, ::Bool)
    @assert length(s_oa) == 3
    cache = PowerConeCache()
    cache.cone = cone
    cache.t = cone.exponent
    cache.s_oa = s_oa
    return cache
end

function add_init_cuts(cache::PowerConeCache, oa_model::JuMP.Model)
    (u, v, w) = cache.s_oa
    t = cache.t
    # add variable bounds and cuts (t, 1-t, ±1)
    JuMP.set_lower_bound(u, 0)
    JuMP.set_lower_bound(v, 0)
    JuMP.@constraints(oa_model, begin
        t * u + (1 - t) * v + w >= 0
        t * u + (1 - t) * v - w >= 0
    end)
    return 4
end

function get_subp_cuts(z::Vector{Float64}, cache::PowerConeCache, oa_model::JuMP.Model)
    p = z[1]
    q = z[2]
    if min(p, q) <= 0
        # z ∉ K
        @warn("dual vector is not in the dual cone")
        return JuMP.AffExpr[]
    end

    # strengthened cut is (p, q, sign(r) * (p/t)^t * (q/(1-t))^(1-t))
    t = cache.t
    r = sign(z[3]) * (p / t)^t * (q / (1 - t))^(1 - t)
    (u, v, w) = cache.s_oa
    cut = JuMP.@expression(oa_model, p * u + q * v + r * w)
    return [cut]
end

function get_sep_cuts(cache::PowerConeCache, oa_model::JuMP.Model)
    (us, vs, ws) = cache.s
    if min(us, vs) <= -1e-7
        error("power cone point violates initial cuts")
    end

    # check s ∉ K
    t = cache.t
    if us >= 0 && vs >= 0 && (us^t * vs^(1 - t) - abs(ws)) > -1e-7
        return JuMP.AffExpr[]
    end

    # gradient cut is (t * (us/vs)^(t-1), (1-t) * (us/vs)^t, -sign(ws))
    # TODO need better approach when u or v near zero
    us = max(us, 1e-8)
    vs = max(vs, 1e-8)
    (u, v, w) = s_vars
    p = t * (us / vs)^(t - 1)
    q = (1 - t) * (us / vs)^t
    cut = JuMP.@expression(oa_model, p * u + q * v - sign(ws) * w)
    return [cut]
end
