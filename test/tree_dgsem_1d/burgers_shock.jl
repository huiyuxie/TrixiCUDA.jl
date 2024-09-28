module Test

include("../test_helpers_1d.jl")

equations = InviscidBurgersEquation1D()

basis = LobattoLegendreBasis(3)
# Use shock capturing techniques to suppress oscillations at discontinuities
indicator_sc = IndicatorHennemannGassner(equations, basis,
                                         alpha_max = 1.0,
                                         alpha_min = 0.001,
                                         alpha_smooth = true,
                                         variable = first)

volume_flux = flux_ec
surface_flux = flux_lax_friedrichs

volume_integral = VolumeIntegralShockCapturingHG(indicator_sc;
                                                 volume_flux_dg = surface_flux,
                                                 volume_flux_fv = surface_flux)

solver = DGSEM(basis, surface_flux, volume_integral)

coordinate_min = 0.0
coordinate_max = 1.0

# Make sure to turn periodicity explicitly off as special boundary conditions are specified
mesh = TreeMesh(coordinate_min, coordinate_max,
                initial_refinement_level = 6,
                n_cells_max = 10_000,
                periodicity = false)

# Discontinuous initial condition (Riemann Problem) leading to a shock to test e.g. correct shock speed.
function initial_condition_shock(x, t, equation::InviscidBurgersEquation1D)
    scalar = x[1] < 0.5 ? 1.5 : 0.5

    return SVector(scalar)
end

# Specify non-periodic boundary conditions
function inflow(x, t, equations::InviscidBurgersEquation1D)
    return initial_condition_shock(0.0, t, equations)
end
boundary_condition_inflow = BoundaryConditionDirichlet(inflow)

function boundary_condition_outflow(u_inner, orientation, normal_direction, x, t,
                                    surface_flux_function,
                                    equations::InviscidBurgersEquation1D)
    # Calculate the boundary flux entirely from the internal solution state
    flux = Trixi.flux(u_inner, normal_direction, equations)

    return flux
end

boundary_conditions = (x_neg = boundary_condition_inflow,
                       x_pos = boundary_condition_outflow)

initial_condition = initial_condition_shock

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver,
                                    boundary_conditions = boundary_conditions)
semi_gpu = SemidiscretizationHyperbolicGPU(mesh, equations, initial_condition, solver,
                                           boundary_conditions = boundary_conditions)

tspan = (0.0, 0.2)

ode = semidiscretize(semi, tspan)
u_ode = copy(ode.u0)
du_ode = similar(u_ode)

# Get CPU data
t = 0.0
(; mesh, equations, initial_condition, boundary_conditions, source_terms, solver, cache) = semi
u = Trixi.wrap_array(u_ode, mesh, equations, solver, cache)
du = Trixi.wrap_array(du_ode, mesh, equations, solver, cache)

# Get GPU data
t_gpu = 0.0
equations_gpu = semi_gpu.equations
mesh_gpu, solver_gpu, cache_gpu = semi_gpu.mesh, semi_gpu.solver, semi_gpu.cache
initial_condition_gpu = semi_gpu.initial_condition
boundary_conditions_gpu = semi_gpu.boundary_conditions
source_terms_gpu = semi_gpu.source_terms
u_gpu = CuArray(u)
du_gpu = CuArray(du)

# Begin tests
@testset "Semidiscretization Process" begin
    @testset "Copy to GPU" begin
        test_copy_to_gpu(du_gpu, u_gpu, du, u, solver, cache)
    end

    @testset "Volume Integral" begin
        test_volume_integral(du_gpu, u_gpu, mesh_gpu, equations_gpu, solver_gpu, cache_gpu,
                             du, u, mesh, equations, solver, cache)
    end

    @testset "Prolong Interfaces" begin
        test_prolong2interfaces(u_gpu, mesh_gpu, equations_gpu, cache_gpu,
                                u, mesh, equations, solver, cache)
    end

    @testset "Interface Flux" begin
        test_interface_flux(mesh_gpu, equations_gpu, solver_gpu, cache_gpu,
                            mesh, equations, solver, cache)
    end

    @testset "Prolong Boundaries" begin
        test_prolong2boundaries(u_gpu, mesh_gpu, boundary_conditions_gpu, equations_gpu, cache_gpu,
                                u, mesh, equations, solver, cache)
    end

    @testset "Boundary Flux" begin
        test_boundary_flux(t_gpu, mesh_gpu, boundary_conditions_gpu, equations_gpu, solver_gpu,
                           cache_gpu, t, mesh, equations, solver, cache)
    end

    @testset "Surface Integral" begin
        test_surface_integral(du_gpu, mesh_gpu, equations_gpu, solver_gpu, cache_gpu,
                              du, u, mesh, equations, solver, cache)
    end

    @testset "Apply Jacobian" begin
        test_jacobian(du_gpu, mesh_gpu, equations_gpu, cache_gpu,
                      du, mesh, equations, solver, cache)
    end

    @testset "Apply Sources" begin
        test_sources(du_gpu, u_gpu, t_gpu, source_terms_gpu, equations_gpu, cache_gpu,
                     du, u, t, source_terms, equations, solver, cache)
    end

    @testset "Copy to CPU" begin
        test_copy_to_cpu(du_gpu, u_gpu, du, u)
    end
end

end # module
