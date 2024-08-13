using Trixi, TrixiGPU
using OrdinaryDiffEq
using Test, CUDA
using Cthulhu

equations = CompressibleEulerEquations1D(1.4f0)

initial_condition = initial_condition_weak_blast_wave

volume_flux = flux_ranocha
solver = DGSEM(polydeg = 3,
               surface_flux = flux_ranocha,
               volume_integral = VolumeIntegralFluxDifferencing(volume_flux))

coordinates_min = (-2.0f0,)
coordinates_max = (2.0f0,)
mesh = TreeMesh(coordinates_min,
                coordinates_max,
                initial_refinement_level = 5,
                n_cells_max = 10_000)

semi = SemidiscretizationHyperbolic(mesh, equations, initial_condition, solver)

@unpack mesh,
equations,
initial_condition,
boundary_conditions,
source_terms,
solver,
cache = semi

t = 0.0f0
tspan = (0.0f0, 0.4f0)

ode = semidiscretize(semi, tspan)
u_ode = copy(ode.u0)
du_ode = similar(u_ode)
u = Trixi.wrap_array(u_ode, mesh, equations, solver, cache)
du = Trixi.wrap_array(du_ode, mesh, equations, solver, cache)

du, u = TrixiGPU.copy_to_device!(du, u)
TrixiGPU.cuda_volume_integral!(du, u, mesh,
                               Trixi.have_nonconservative_terms(equations),
                               equations,
                               solver.volume_integral,
                               solver)
