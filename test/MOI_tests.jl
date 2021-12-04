# MOI tests

module TestMOI

using Test
import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
import MOIPajarito

function runtests(oa_solver, conic_solver)
    @testset "iterative method" run_moi_tests(true, oa_solver, conic_solver)
    @testset "OA solver driven method" run_moi_tests(false, oa_solver, conic_solver)
    return
end

function run_moi_tests(use_iter::Bool, oa_solver, conic_solver)
    paj_opt = MOIPajarito.Optimizer()
    MOI.set(paj_opt, MOI.Silent(), true)
    MOI.set(paj_opt, MOI.RawOptimizerAttribute("use_iterative_method"), use_iter)
    MOI.set(paj_opt, MOI.RawOptimizerAttribute("oa_solver"), oa_solver)
    MOI.set(paj_opt, MOI.RawOptimizerAttribute("conic_solver"), conic_solver)

    caching_opt = MOIU.CachingOptimizer(
        MOIU.UniversalFallback(MOIU.Model{Float64}()),
        MOI.Bridges.full_bridge_optimizer(paj_opt, Float64),
    )

    config = MOI.Test.Config(
        atol = 1e-4,
        rtol = 1e-4,
        exclude = Any[
            MOI.delete,
            MOI.ConstraintDual,
            MOI.ConstraintBasisStatus,
            MOI.DualObjectiveValue,
            MOI.SolverVersion,
        ],
    )

    excludes = String[
    # # invalid model:
    # # "test_constraint_ZeroOne_bounds_3",
    # "test_linear_VectorAffineFunction_empty_row",
    # # CachingOptimizer does not throw if optimizer not attached:
    # "test_model_copy_to_UnsupportedAttribute",
    # "test_model_copy_to_UnsupportedConstraint",
]

    includes = String[
    # "test_conic_SecondOrderCone",
    # "test_conic_SecondOrderCone_negative_post_bound_2",
    # "test_conic_SecondOrderCone_Nonnegatives",
    # "test_conic_SecondOrderCone_INFEASIBLE",
]

    MOI.Test.runtests(caching_opt, config, exclude = excludes, include = includes)
    return
end

end
