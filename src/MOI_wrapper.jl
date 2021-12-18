# MathOptInterface wrapper of Pajarito solver

_is_empty(::Nothing) = true
_is_empty(opt::MOI.AbstractOptimizer) = MOI.is_empty(opt)

MOI.is_empty(opt::Optimizer) = (_is_empty(opt.oa_opt) && _is_empty(opt.conic_opt))

MOI.empty!(opt::Optimizer) = empty_optimize(opt)

MOI.get(::Optimizer, ::MOI.SolverName) = "Pajarito"

MOI.supports(::Optimizer, ::MOI.Silent) = true

function MOI.set(opt::Optimizer, ::MOI.Silent, value::Bool)
    opt.verbose = !value
    return
end

MOI.get(opt::Optimizer, ::MOI.Silent) = !opt.verbose

MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

function MOI.set(opt::Optimizer, ::MOI.TimeLimitSec, value::Union{Real, Nothing})
    opt.time_limit = something(value, Inf)
    return
end

function MOI.get(opt::Optimizer, ::MOI.TimeLimitSec)
    if isfinite(opt.time_limit)
        return opt.time_limit
    end
    return
end

function MOI.get(opt::Optimizer, ::MOI.SolveTimeSec)
    if isnan(opt.solve_time)
        error("solve has not been called")
    end
    return opt.solve_time
end

MOI.get(opt::Optimizer, ::MOI.RawStatusString) = string(opt.status)

function MOI.set(opt::Optimizer, param::MOI.RawOptimizerAttribute, value)
    return setproperty!(opt, Symbol(param.name), value)
end

function MOI.get(opt::Optimizer, param::MOI.RawOptimizerAttribute)
    return getproperty(opt, Symbol(param.name))
end

function MOI.supports(
    ::Optimizer,
    ::Union{MOI.ObjectiveSense, MOI.ObjectiveFunction{<:Union{VI, SAF}}},
)
    return true
end

function MOI.supports_constraint(opt::Optimizer, F::Type{VI}, S::Type{MOI.Integer})
    return MOI.supports_constraint(get_oa_opt(opt), F, S)
end

# cone must be supported by both Pajarito and the conic solver
function MOI.supports_constraint(
    opt::Optimizer,
    F::Type{<:Union{VV, VAF}},
    S::Type{<:Union{MOI.Zeros, MOI.Nonnegatives, Cones.OACone}},
)
    return MOI.supports_constraint(get_conic_opt(opt), F, S)
end

MOI.supports(::Optimizer, ::MOI.VariablePrimalStart, ::Type{VI}) = true

MOI.optimize!(opt::Optimizer) = optimize(opt)

MOI.get(opt::Optimizer, ::MOI.TerminationStatus) = opt.status

function MOI.get(opt::Optimizer, attr::MOI.PrimalStatus)
    if attr.result_index != 1
        return MOI.NO_SOLUTION
    end
    term_status = MOI.get(opt, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        return MOI.FEASIBLE_POINT
    elseif term_status == MOI.ALMOST_OPTIMAL
        return MOI.NEARLY_FEASIBLE_POINT
    end
    return MOI.NO_SOLUTION
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function _adjust_obj(opt::Optimizer, value::Float64)
    sense_mul = (opt.obj_sense == MOI.MAX_SENSE ? -1 : 1)
    return sense_mul * (opt.obj_offset + value)
end

function MOI.get(opt::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(opt, attr)
    return _adjust_obj(opt, opt.obj_value)
end

MOI.get(opt::Optimizer, ::MOI.ObjectiveBound) = _adjust_obj(opt, opt.obj_bound)

MOI.get(opt::Optimizer, ::MOI.ResultCount) = 1

function MOI.get(opt::Optimizer, attr::MOI.VariablePrimal, vi::VI)
    MOI.check_result_index_bounds(opt, attr)
    return opt.incumbent[vi.value]
end
