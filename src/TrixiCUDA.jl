module TrixiCUDA

# Include other packages that are used in TrixiCUDA.jl
# using Reexport: @reexport

using CUDA: @cuda, CuArray, HostKernel,
            threadIdx, blockIdx, blockDim, similar, launch_configuration

using Trixi: AbstractEquations, TreeMesh, DGSEM,
             BoundaryConditionPeriodic, SemidiscretizationHyperbolic,
             VolumeIntegralWeakForm, VolumeIntegralFluxDifferencing, VolumeIntegralShockCapturingHG,
             flux, ntuple, nvariables,
             True, False,
             wrap_array, compute_coefficients, have_nonconservative_terms,
             boundary_condition_periodic,
             set_log_type!, set_sqrt_type!

import Trixi: get_node_vars, get_node_coords, get_surface_node_vars

using SciMLBase: ODEProblem, FullSpecialize

using StrideArrays: PtrArray

using StaticArrays: SVector

# Include other source files
include("auxiliary/auxiliary.jl")
include("semidiscretization/semidiscretization.jl")
include("solvers/solvers.jl")

# Change to use the Base.log and Base.sqrt - need to be fixed to avoid outputs
set_log_type!("log_Base")
set_sqrt_type!("sqrt_Base")

# Export the public APIs
export SemidiscretizationHyperbolicGPU
export semidiscretizeGPU

end
