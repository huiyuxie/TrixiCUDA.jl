# Test suite for DGSEM solver with tree mesh on 1D, 2D, and 3D problems.

# Test suite for 1D problems
function run_dgsem_tree_tests_1D(semi, tspan)
    # Get CPU data
    (; mesh, equations, initial_condition, boundary_conditions, source_terms, solver, cache) = semi

    # Get GPU data
    equations_gpu = deepcopy(equations)
    mesh_gpu, solver_gpu, cache_gpu = deepcopy(mesh), deepcopy(solver), deepcopy(cache)
    boundary_conditions_gpu, source_terms_gpu = deepcopy(boundary_conditions),
                                                deepcopy(source_terms)

    # Set initial time
    t = t_gpu = 0.0

    # Get initial data
    ode = semidiscretize(semi, tspan)
    u_ode = copy(ode.u0)
    du_ode = similar(u_ode)
    u = Trixi.wrap_array(u_ode, mesh, equations, solver, cache)
    du = Trixi.wrap_array(du_ode, mesh, equations, solver, cache)

    # Copy data to device
    du_gpu, u_gpu = TrixiCUDA.copy_to_device!(du, u)
    # Reset data on host
    Trixi.reset_du!(du, solver, cache)

    # Test `cuda_volume_integral!`
    TrixiCUDA.cuda_volume_integral!(du_gpu, u_gpu, mesh_gpu,
                                    Trixi.have_nonconservative_terms(equations_gpu),
                                    equations_gpu, solver_gpu.volume_integral, solver_gpu,
                                    cache_gpu)
    Trixi.calc_volume_integral!(du, u, mesh, Trixi.have_nonconservative_terms(equations),
                                equations, solver.volume_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_prolong2interfaces!`
    TrixiCUDA.cuda_prolong2interfaces!(u_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.prolong2interfaces!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.interfaces.u ≈ cache.interfaces.u

    # Test `cuda_interface_flux!`
    TrixiCUDA.cuda_interface_flux!(mesh_gpu, Trixi.have_nonconservative_terms(equations_gpu),
                                   equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_interface_flux!(cache.elements.surface_flux_values, mesh,
                               Trixi.have_nonconservative_terms(equations), equations,
                               solver.surface_integral, solver, cache)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_prolong2boundaries!`
    TrixiCUDA.cuda_prolong2boundaries!(u_gpu, mesh_gpu, boundary_conditions_gpu, equations_gpu,
                                       cache_gpu)
    Trixi.prolong2boundaries!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.boundaries.u ≈ cache.boundaries.u

    # Test `cuda_boundary_flux!`
    TrixiCUDA.cuda_boundary_flux!(t_gpu, mesh_gpu, boundary_conditions_gpu,
                                  Trixi.have_nonconservative_terms(equations_gpu), equations_gpu,
                                  solver_gpu, cache_gpu)
    Trixi.calc_boundary_flux!(cache, t, boundary_conditions, mesh, equations,
                              solver.surface_integral, solver)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_surface_integral!`
    TrixiCUDA.cuda_surface_integral!(du_gpu, mesh_gpu, equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_surface_integral!(du, u, mesh, equations, solver.surface_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_jacobian!`
    TrixiCUDA.cuda_jacobian!(du_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.apply_jacobian!(du, mesh, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_sources!`
    TrixiCUDA.cuda_sources!(du_gpu, u_gpu, t_gpu, source_terms_gpu, equations_gpu, cache_gpu)
    Trixi.calc_sources!(du, u, t, source_terms, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Copy data back to host
    du_cpu, u_cpu = TrixiCUDA.copy_to_host!(du_gpu, u_gpu)
end

# Test suite for 2D problems
function run_dgsem_tree_tests_2D(semi, tspan)
    # Get CPU data
    (; mesh, equations, initial_condition, boundary_conditions, source_terms, solver, cache) = semi

    # Get GPU data
    equations_gpu = deepcopy(equations)
    mesh_gpu, solver_gpu, cache_gpu = deepcopy(mesh), deepcopy(solver), deepcopy(cache)
    boundary_conditions_gpu, source_terms_gpu = deepcopy(boundary_conditions),
                                                deepcopy(source_terms)

    # Set initial time
    t = t_gpu = 0.0

    # Get initial data
    ode = semidiscretize(semi, tspan)
    u_ode = copy(ode.u0)
    du_ode = similar(u_ode)
    u = Trixi.wrap_array(u_ode, mesh, equations, solver, cache)
    du = Trixi.wrap_array(du_ode, mesh, equations, solver, cache)

    # Copy data to device
    du_gpu, u_gpu = TrixiCUDA.copy_to_device!(du, u)
    # Reset data on host
    Trixi.reset_du!(du, solver, cache)

    # Test `cuda_volume_integral!`
    TrixiCUDA.cuda_volume_integral!(du_gpu, u_gpu, mesh_gpu,
                                    Trixi.have_nonconservative_terms(equations_gpu),
                                    equations_gpu, solver_gpu.volume_integral, solver_gpu,
                                    cache_gpu)
    Trixi.calc_volume_integral!(du, u, mesh, Trixi.have_nonconservative_terms(equations),
                                equations, solver.volume_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_prolong2interfaces!`
    TrixiCUDA.cuda_prolong2interfaces!(u_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.prolong2interfaces!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.interfaces.u ≈ cache.interfaces.u

    # Test `cuda_interface_flux!`
    TrixiCUDA.cuda_interface_flux!(mesh_gpu, Trixi.have_nonconservative_terms(equations_gpu),
                                   equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_interface_flux!(cache.elements.surface_flux_values, mesh,
                               Trixi.have_nonconservative_terms(equations), equations,
                               solver.surface_integral, solver, cache)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_prolong2boundaries!`
    TrixiCUDA.cuda_prolong2boundaries!(u_gpu, mesh_gpu, boundary_conditions_gpu, equations_gpu,
                                       cache_gpu)
    Trixi.prolong2boundaries!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.boundaries.u ≈ cache.boundaries.u

    # Test `cuda_boundary_flux!`
    TrixiCUDA.cuda_boundary_flux!(t_gpu, mesh_gpu, boundary_conditions_gpu,
                                  Trixi.have_nonconservative_terms(equations_gpu), equations_gpu,
                                  solver_gpu, cache_gpu)
    Trixi.calc_boundary_flux!(cache, t, boundary_conditions, mesh, equations,
                              solver.surface_integral, solver)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_prolong2mortars!`
    TrixiCUDA.cuda_prolong2mortars!(u_gpu, mesh_gpu, TrixiCUDA.check_cache_mortars(cache_gpu),
                                    solver_gpu, cache_gpu)
    Trixi.prolong2mortars!(cache, u, mesh, equations,
                           solver.mortar, solver.surface_integral, solver)
    @test_approx cache_gpu.mortars.u_upper ≈ cache.mortars.u_upper
    @test_approx cache_gpu.mortars.u_lower ≈ cache.mortars.u_lower

    # Test `cuda_mortar_flux!`
    TrixiCUDA.cuda_mortar_flux!(mesh_gpu, TrixiCUDA.check_cache_mortars(cache_gpu),
                                Trixi.have_nonconservative_terms(equations_gpu), equations_gpu,
                                solver_gpu, cache_gpu)
    Trixi.calc_mortar_flux!(cache.elements.surface_flux_values, mesh,
                            Trixi.have_nonconservative_terms(equations), equations,
                            solver.mortar, solver.surface_integral, solver, cache)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_surface_integral!`
    TrixiCUDA.cuda_surface_integral!(du_gpu, mesh_gpu, equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_surface_integral!(du, u, mesh, equations, solver.surface_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_jacobian!`
    TrixiCUDA.cuda_jacobian!(du_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.apply_jacobian!(du, mesh, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_sources!`
    TrixiCUDA.cuda_sources!(du_gpu, u_gpu, t_gpu, source_terms_gpu, equations_gpu, cache_gpu)
    Trixi.calc_sources!(du, u, t, source_terms, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Copy data back to host
    du_cpu, u_cpu = TrixiCUDA.copy_to_host!(du_gpu, u_gpu)
end

# Test suite for 3D problems
function run_dgsem_tree_tests_3D(semi, tspan)
    # Get CPU data
    (; mesh, equations, initial_condition, boundary_conditions, source_terms, solver, cache) = semi

    # Get GPU data
    equations_gpu = deepcopy(equations)
    mesh_gpu, solver_gpu, cache_gpu = deepcopy(mesh), deepcopy(solver), deepcopy(cache)
    boundary_conditions_gpu, source_terms_gpu = deepcopy(boundary_conditions),
                                                deepcopy(source_terms)

    # Set initial time
    t = t_gpu = 0.0

    # Get initial data
    ode = semidiscretize(semi, tspan)
    u_ode = copy(ode.u0)
    du_ode = similar(u_ode)
    u = Trixi.wrap_array(u_ode, mesh, equations, solver, cache)
    du = Trixi.wrap_array(du_ode, mesh, equations, solver, cache)

    # Copy data to device
    du_gpu, u_gpu = TrixiCUDA.copy_to_device!(du, u)
    # Reset data on host
    Trixi.reset_du!(du, solver, cache)

    # Test `cuda_volume_integral!`
    TrixiCUDA.cuda_volume_integral!(du_gpu, u_gpu, mesh_gpu,
                                    Trixi.have_nonconservative_terms(equations_gpu),
                                    equations_gpu, solver_gpu.volume_integral, solver_gpu,
                                    cache_gpu)
    Trixi.calc_volume_integral!(du, u, mesh, Trixi.have_nonconservative_terms(equations),
                                equations, solver.volume_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_prolong2interfaces!`
    TrixiCUDA.cuda_prolong2interfaces!(u_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.prolong2interfaces!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.interfaces.u ≈ cache.interfaces.u

    # Test `cuda_interface_flux!`
    TrixiCUDA.cuda_interface_flux!(mesh_gpu, Trixi.have_nonconservative_terms(equations_gpu),
                                   equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_interface_flux!(cache.elements.surface_flux_values, mesh,
                               Trixi.have_nonconservative_terms(equations), equations,
                               solver.surface_integral, solver, cache)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_prolong2boundaries!`
    TrixiCUDA.cuda_prolong2boundaries!(u_gpu, mesh_gpu, boundary_conditions_gpu, equations_gpu,
                                       cache_gpu)
    Trixi.prolong2boundaries!(cache, u, mesh, equations, solver.surface_integral, solver)
    @test_approx cache_gpu.boundaries.u ≈ cache.boundaries.u

    # Test `cuda_boundary_flux!`
    TrixiCUDA.cuda_boundary_flux!(t_gpu, mesh_gpu, boundary_conditions_gpu,
                                  Trixi.have_nonconservative_terms(equations_gpu), equations_gpu,
                                  solver_gpu, cache_gpu)
    Trixi.calc_boundary_flux!(cache, t, boundary_conditions, mesh, equations,
                              solver.surface_integral, solver)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_prolong2mortars!`
    TrixiCUDA.cuda_prolong2mortars!(u_gpu, mesh_gpu, TrixiCUDA.check_cache_mortars(cache_gpu),
                                    solver_gpu, cache_gpu)
    Trixi.prolong2mortars!(cache, u, mesh, equations,
                           solver.mortar, solver.surface_integral, solver)
    @test_approx cache_gpu.mortars.u_upper_left ≈ cache.mortars.u_upper_left
    @test_approx cache_gpu.mortars.u_upper_right ≈ cache.mortars.u_upper_right
    @test_approx cache_gpu.mortars.u_lower_left ≈ cache.mortars.u_lower_left
    @test_approx cache_gpu.mortars.u_lower_right ≈ cache.mortars.u_lower_right

    # Test `cuda_mortar_flux!`
    TrixiCUDA.cuda_mortar_flux!(mesh_gpu, TrixiCUDA.check_cache_mortars(cache_gpu),
                                Trixi.have_nonconservative_terms(equations_gpu), equations_gpu,
                                solver_gpu, cache_gpu)
    Trixi.calc_mortar_flux!(cache.elements.surface_flux_values, mesh,
                            Trixi.have_nonconservative_terms(equations), equations,
                            solver.mortar, solver.surface_integral, solver, cache)
    @test_approx cache_gpu.elements.surface_flux_values ≈ cache.elements.surface_flux_values

    # Test `cuda_surface_integral!`
    TrixiCUDA.cuda_surface_integral!(du_gpu, mesh_gpu, equations_gpu, solver_gpu, cache_gpu)
    Trixi.calc_surface_integral!(du, u, mesh, equations, solver.surface_integral, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_jacobian!`
    TrixiCUDA.cuda_jacobian!(du_gpu, mesh_gpu, equations_gpu, cache_gpu)
    Trixi.apply_jacobian!(du, mesh, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Test `cuda_sources!`
    TrixiCUDA.cuda_sources!(du_gpu, u_gpu, t_gpu, source_terms_gpu, equations_gpu, cache_gpu)
    Trixi.calc_sources!(du, u, t, source_terms, equations, solver, cache)
    @test_approx du_gpu ≈ du

    # Copy data back to host
    du_cpu, u_cpu = TrixiCUDA.copy_to_host!(du_gpu, u_gpu)
end
