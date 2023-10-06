/*
This file is for internal test purposes only and is not part of the Trixi GPU framework. It
implements launch configurations and GPU kernels using CUDA and C++. The focus is on solving PDEs
with the DG method for 2D problems.
*/

// Include libraries and header files
#include "arrays.h"
#include "configurators.h"
#include "header.h"

/* CUDA kernels
====================================================================================================
Optimization
- Try to use shared memory
- Compare linear memory and array memeory
- Run on mutiple GPUs
====================================================================================================
*/

// TODO: Convert raw `du` and `u` to array structures

// Copy data from host to device
__host__ std::pair<Array4D, Array4D> copyToGPU(Array4D duHost, Array4D uHost) {
    Array4D duDevice, uDevice;
    int width = duHost.width;
    int height1 = duHost.height1;
    int height2 = duHost.height2;
    int depth = duHost.depth;

    duDevice.initOnDevice(width, height1, height2, depth);
    uDevice.initOnDevice(width, height1, height2, depth);

    copyToDevice(duHost, duDevice);
    copyToDevice(uHost, uDevice);

    // Can also be reused, please compare the performance
    duHost.freeOnHost();
    uHost.freeOnHost();

    return {duDevice, uDevice};
}

// Copy data from device to host
__host__ std::pair<Array4D, Array4D> copyToCPU(Array4D duDevice, Array4D uDevice) {
    Array4D duHost, uHost;
    int width = duDevice.width;
    int height1 = duDevice.height1;
    int height2 = duDevice.height2;
    int depth = duDevice.depth;

    duHost.initOnHost(width, height1, height2, depth);
    uHost.initOnHost(width, height1, height2, depth);

    copyToCPU(duDevice, duHost);
    copyToCPU(uDevice, uHost);

    duDevice.freeOnDevice();
    uDevice.freeOnDevice();

    return {duHost, uHost};
}

/* // Copy data from host to device (from double to float)
void copy_to_gpu(float ***&du_device, double ***du_host, float ***&u_device, double ***u_host,
                 int width, int height, int depth) {

    // 3D extent for allocation
    cudaExtent extent = make_cudaExtent(width * sizeof(float), height ^ 2,
                                        depth); // We treat it as a 3D array with height = height^2

    // Allocate memory for `du` on the GPU and set to zero
    cudaPitchedPtr devDuPitchedPtr;
    cudaMalloc3D(&devDuPitchedPtr, extent);
    cudaMemset3D(devDuPitchedPtr, 0, extent);

    // Allocate memory for `u` on the GPU
    cudaPitchedPtr devUPitchedPtr;
    cudaMalloc3D(&devUPitchedPtr, extent);

    // Convert `u` from double to float and copy to GPU
    cudaMemcpy3DParms copyParams = {0};
    float *temp_u_float = new float[width * height ^ 2 * depth];

    int idx = 0;
    for (int z = 0; z < depth; z++) {
        for (int y = 0; y < height ^ 2; y++) {
            for (int x = 0; x < width; x++) {
                temp_u_float[idx++] = static_cast<float>(u_host[z][y][x]);
            }
        }
    }

    copyParams.srcPtr =
        make_cudaPitchedPtr((void *)temp_u_float, width * sizeof(float), width, height ^ 2);
    copyParams.dstPtr = devUPitchedPtr;
    copyParams.extent = extent;
    copyParams.kind = cudaMemcpyHostToDevice;
    cudaMemcpy3D(&copyParams);

    // Assign the pointers to the device memory
    du_device = (float ***)devDuPitchedPtr.ptr;
    u_device = (float ***)devUPitchedPtr.ptr;

    delete[] temp_u_float;
}

// Copy data from device to host (from float to double)
void copy_to_cpu(float ***du_device, double ***&du_host, float ***u_device, double ***&u_host,
                 int width, int height, int depth) {

    // 3D extent for copy
    cudaExtent extent = make_cudaExtent(width * sizeof(float), height ^ 2,
                                        depth); // We treat it as a 3D array with height = height^2

    // Temporary buffer for float data from the device
    float *temp_u_float = new float[width * height ^ 2 * depth];
    float *temp_du_float = new float[width * height ^ 2 * depth];

    cudaMemcpy3DParms copyParamsU = {0};
    copyParamsU.dstPtr =
        make_cudaPitchedPtr((void *)temp_u_float, width * sizeof(float), width, height ^ 2);
    copyParamsU.srcPtr =
        make_cudaPitchedPtr((void *)u_device, width * sizeof(float), width, height ^ 2);
    copyParamsU.extent = extent;
    copyParamsU.kind = cudaMemcpyDeviceToHost;
    cudaMemcpy3D(&copyParamsU);

    cudaMemcpy3DParms copyParamsDu = {0};
    copyParamsDu.dstPtr =
        make_cudaPitchedPtr((void *)temp_du_float, width * sizeof(float), width, height ^ 2);
    copyParamsDu.srcPtr =
        make_cudaPitchedPtr((void *)du_device, width * sizeof(float), width, height ^ 2);
    copyParamsDu.extent = extent;
    copyParamsDu.kind = cudaMemcpyDeviceToHost;
    cudaMemcpy3D(&copyParamsDu);

    // Convert float data back to double and store in `u_host` and `du_host`
    int idx = 0;
    for (int z = 0; z < depth; z++) {
        for (int y = 0; y < height ^ 2; y++) {
            for (int x = 0; x < width; x++) {
                u_host[z][y][x] = static_cast<double>(temp_u_float[idx]);
                du_host[z][y][x] = static_cast<double>(temp_du_float[idx]);
                idx++;
            }
        }
    }

    delete[] temp_u_float;
    delete[] temp_du_float;

    // Free GPU memory
    cudaFree(du_device);
    cudaFree(u_device);
} */

// CUDA kernel for calculating fluxes along normal direction 1
__global__ void flux_kernel(float *flux_arr, float *u, int u_dim1, int u_dim2, int u_dim3,
                            AbstractEquations equations) { // TODO: `AbstractEquations`

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    if (j < u_dim2 && k < u_dim3) {
        float *u_node = get_nodes_vars(u, equations, j, k); // TODO: `get_nodes_vars`

        float *flux_node = flux(u_node, 1, equations); // TODO: `flux`

        for (int ii = 0; ii < u_dim1; ii++) {
            flux_arr[ii * u_dim2 * u_dim3 + j * u_dim3 + k] = flux_node[ii];
        }

        // Make sure to deallocate any memory you dynamically allocated
        delete[] u_node;
        delete[] flux_node;
    }
}

// CUDA kernel for calculating weak form
__global__ void weak_form_kernel(float *du, float *derivative_dhat, float *flux_arr, int du_dim1,
                                 int du_dim2, int du_dim3) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.z * blockDim.z + threadIdx.z;

    if (i < du_dim1 && j < du_dim2 && k < du_dim3) {
        for (int ii = 0; ii < du_dim2; ii++) {
            int du_idx = i * du_dim2 * du_dim3 + j * du_dim3 + k;
            int derivative_idx = j * du_dim2 + ii;
            int flux_idx = i * du_dim2 * du_dim3 + ii * du_dim3 + k;

            du[du_idx] += derivative_dhat[derivative_idx] * flux_arr[flux_idx];
        }
    }
}

// CUDA kernel for calculating volume fluxes in direction x
__global__ void volume_flux_kernel(float *volume_flux_arr, float *u, int u_dim1, int u_dim2,
                                   int u_dim3, AbstractEquations equations) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    if (j < u_dim2 * u_dim2 && k < u_dim3) {
        int j1 = j / u_dim2;
        int j2 = j % u_dim2;

        float *u_node = get_nodes_vars(u, equations, j1, k);  // TODO: `get_nodes_vars`
        float *u_node1 = get_nodes_vars(u, equations, j2, k); // TODO: `get_nodes_vars`

        float *volume_flux_node = volume_flux(u_node, u_node1, 1, equations); // TODO: `volume_flux`

        for (int ii = 0; ii < u_dim1; ii++) {
            volume_flux_arr[ii * u_dim2 * u_dim2 * u_dim3 + j1 * u_dim2 * u_dim3 + j2 * u_dim3 +
                            k] = volume_flux_node[ii];
        }

        // Make sure to deallocate any memory you dynamically allocated
        delete[] u_node;
        delete[] u_node1;
        delete[] volume_flux_node;
    }
}

// CUDA kernel for calculating symmetric and nonsymmetric fluxes in direction x
__global__ void symmetric_noncons_flux_kernel(float *symmetric_flux_arr, float *noncons_flux_arr,
                                              float *u, float *derivative_split, int u_dim1,
                                              int u_dim2, int u_dim3, AbstractEquations equations) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    if (j < u_dim2 * u_dim2 && k < u_dim3) {
        int j1 = j / u_dim2;
        int j2 = j % u_dim2;

        float *u_node = get_nodes_vars(u, equations, j1, k);
        float *u_node1 = get_nodes_vars(u, equations, j2, k);

        float *symmetric_flux_node =
            symmetric_flux(u_node, u_node1, 1, equations); // TODO: `symmetric_flux`
        float *noncons_flux_node =
            nonconservative_flux(u_node, u_node1, 1, equations); // TODO: `nonconservative_flux`

        for (int ii = 0; ii < u_dim1; ii++) {
            symmetric_flux_arr[ii * u_dim2 * u_dim2 * u_dim3 + j1 * u_dim2 * u_dim3 + j2 * u_dim3 +
                               k] = symmetric_flux_node[ii];
            noncons_flux_arr[ii * u_dim2 * u_dim2 * u_dim3 + j1 * u_dim2 * u_dim3 + j2 * u_dim3 +
                             k] = noncons_flux_node[ii] * derivative_split[j1 * u_dim2 + j2];
        }

        // Deallocate dynamically allocated memory
        delete[] u_node;
        delete[] u_node1;
        delete[] symmetric_flux_node;
        delete[] noncons_flux_node;
    }
}

// CUDA kernel for calculating volume integrals
__global__ void volume_integral_kernel(float *du, float *derivative_split, float *volume_flux_arr,
                                       int du_dim1, int du_dim2, int du_dim3) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.z * blockDim.z + threadIdx.z;

    if (i < du_dim1 && j < du_dim2 && k < du_dim3) {

        // The size of the second axis of `du` is used in the loop iteration
        // This assumes that the second dimension of `du` and `derivative_split` are the same
        for (int ii = 0; ii < du_dim2; ++ii) {
            du[i * du_dim2 * du_dim3 + j * du_dim3 + k] +=
                derivative_split[j * du_dim2 + ii] *
                volume_flux_arr[i * du_dim2 * du_dim2 * du_dim3 + j * du_dim2 * du_dim3 +
                                ii * du_dim3 + k];
        }
    }
}

// CUDA kernel for calculating symmetric and nonsymmetric volume integrals
__global__ void volume_integral_kernel(float *du, float *derivative_split,
                                       float *symmetric_flux_arr, float *noncons_flux_arr,
                                       int du_dim1, int du_dim2, int du_dim3) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.z * blockDim.z + threadIdx.z;

    if (i < du_dim1 && j < du_dim2 && k < du_dim3) {
        float integral_contribution = 0.0f;

        // The size of the second axis of du is used in the loop iteration
        // This assumes that the second dimension of `du` and `derivative_split` are the same
        for (int ii = 0; ii < du_dim2; ++ii) {
            du[i * du_dim2 * du_dim3 + j * du_dim3 + k] +=
                derivative_split[j * du_dim2 + ii] *
                symmetric_flux_arr[i * du_dim2 * du_dim2 * du_dim3 + j * du_dim2 * du_dim3 +
                                   ii * du_dim3 + k];

            integral_contribution += noncons_flux_arr[i * du_dim2 * du_dim2 * du_dim3 +
                                                      j * du_dim2 * du_dim3 + ii * du_dim3 + k];
        }

        du[i * du_dim2 * du_dim3 + j * du_dim3 + k] += 0.5f * integral_contribution;
    }
}

// Launch CUDA kernels to calculate volume integrals

// CUDA kernel for prolonging two interfaces in direction x
__global__ void prolong_interfaces_kernel(float *interfaces_u, float *u, int *neighbor_ids,
                                          int interfaces_u_dim2, int interfaces_u_dim3, int u_dim2,
                                          int u_dim3) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    // Ensure that we don't go out of bounds
    if (j < interfaces_u_dim2 && k < interfaces_u_dim3) {
        int left_element = neighbor_ids[k];
        int right_element = neighbor_ids[interfaces_u_dim3 + k];

        // Memory access (considering flattened arrays for simplicity)
        interfaces_u[j * interfaces_u_dim3 + k] =
            u[j * u_dim2 * u_dim3 + (u_dim2 - 1) * u_dim3 + left_element - 1];
        interfaces_u[interfaces_u_dim2 * interfaces_u_dim3 + j * interfaces_u_dim3 + k] =
            u[j * u_dim2 * u_dim3 + right_element - 1];
    }
}

// Launch CUDA kernel to prolong solution to interfaces

// CUDA kernel for calculating surface fluxes
__global__ void surface_flux_kernel(float *surface_flux_arr, float *interfaces_u,
                                    int surface_flux_arr_dim2, int surface_flux_arr_dim3,
                                    AbstractEquations equations) {

    int k = blockIdx.x * blockDim.x + threadIdx.x;

    if (k < surface_flux_arr_dim3) {
        float *u_ll, *u_rr;
        get_surface_node_vars(interfaces_u, equations, k, u_ll,
                              u_rr); // TODO: `get_surface_node_vars`

        float *surface_flux_node = surface_flux(u_ll, u_rr, 1, equations); // TODO: `surface_flux`

        for (int jj = 0; jj < surface_flux_arr_dim2; jj++) {
            surface_flux_arr[jj * surface_flux_arr_dim3 + k] =
                surface_flux_node[jj]; // Adjusted for flattened array
        }
    }
}

// CUDA kernel for calculating surface and both nonconservative fluxes
__global__ void surface_noncons_flux_kernel(float *surface_flux_arr, float *interfaces_u,
                                            float *noncons_left_arr, float *noncons_right_arr,
                                            int surface_flux_arr_dim3,
                                            AbstractEquations equations) {

    int k = (blockIdx.x * blockDim.x) + threadIdx.x;

    if (k < surface_flux_arr_dim3) {
        float *u_ll, *u_rr;
        get_surface_node_vars(interfaces_u, equations, k, u_ll,
                              u_rr); // TODO: `get_surface_node_vars`

        float *surface_flux_node = surface_flux(u_ll, u_rr, 1, equations); // TODO: `surface_flux`
        float *noncons_left_node =
            nonconservative_flux(u_ll, u_rr, 1, equations); // TODO: `nonconservative_flux`
        float *noncons_right_node =
            nonconservative_flux(u_rr, u_ll, 1, equations); // TODO: `nonconservative_flux`

        for (int jj = 0; jj < surface_flux_arr_dim3; ++jj) {
            surface_flux_arr[jj * surface_flux_arr_dim3 + k] =
                surface_flux_node[jj]; // Adjusted based on the 1D memory layout
            noncons_left_arr[jj * surface_flux_arr_dim3 + k] =
                noncons_left_node[jj]; // Adjusted based on the 1D memory layout
            noncons_right_arr[jj * surface_flux_arr_dim3 + k] =
                noncons_right_node[jj]; // Adjusted based on the 1D memory layout
        }
    }
}

// CUDA kernel for setting interface fluxes on orientation 1
__global__ void interface_flux_kernel(float *surface_flux_values, float *surface_flux_arr,
                                      int *neighbor_ids, int surface_flux_values_dim1,
                                      int surface_flux_values_dim3, int surface_flux_arr_dim3) {

    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    int k = (blockIdx.y * blockDim.y) + threadIdx.y;

    if (i < surface_flux_values_dim1 && k < surface_flux_arr_dim3) {
        int left_id = neighbor_ids[k];
        int right_id = neighbor_ids[surface_flux_arr_dim3 + k];

        // Assuming `surface_flux_values` and `surface_flux_arr` are 3D arrays flattened to 1D
        // The indexing will depend on how the arrays are structured in memory
        surface_flux_values[i * 2 * surface_flux_values_dim3 + 1 * surface_flux_values_dim3 +
                            left_id - 1] = surface_flux_arr[i * surface_flux_arr_dim3 + k];
        surface_flux_values[i * 2 * surface_flux_values_dim3 + right_id - 1] =
            surface_flux_arr[i * surface_flux_arr_dim3 + k];
    }
}

// CUDA kernel for setting interface fluxes on orientation 1
__global__ void interface_flux_kernel(float *surface_flux_values, float *surface_flux_arr,
                                      float *noncons_left_arr, float *noncons_right_arr,
                                      int *neighbor_ids, int surface_flux_values_dim1,
                                      int surface_flux_values_dim3, int surface_flux_arr_dim3) {

    int i = (blockIdx.x * blockDim.x) + threadIdx.x;
    int k = (blockIdx.y * blockDim.y) + threadIdx.y;

    if (i < surface_flux_values_dim1 && k < surface_flux_arr_dim3) {
        int left_id = neighbor_ids[k];
        int right_id = neighbor_ids[surface_flux_arr_dim3 + k];

        // Assuming `surface_flux_values` and `surface_flux_arr` are 3D arrays flattened to 1D
        // The indexing will depend on how the arrays are structured in memory
        surface_flux_values[i * 2 * surface_flux_values_dim3 + 1 * surface_flux_values_dim3 +
                            left_id - 1] = surface_flux_arr[i * surface_flux_arr_dim3 + k] +
                                           0.5f * noncons_left_arr[i * surface_flux_arr_dim3 + k];
        surface_flux_values[i * 2 * surface_flux_values_dim3 + right_id - 1] =
            surface_flux_arr[i * surface_flux_arr_dim3 + k] +
            0.5f * noncons_right_arr[i * surface_flux_arr_dim3 + k];
    }
}

// Launch CUDA kernels to calculate interface fluxes

// CUDA kernel for prolonging two boundaries in direction x
__global__ void prolong_boundaries_kernel(float *boundaries_u, float *u, int *neighbor_ids,
                                          int *neighbor_sides, int boundaries_u_dim2,
                                          int boundaries_u_dim3, int u_dim2, int u_dim3) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    // Assuming that 3D arrays are flattened to 1D
    if (j < boundaries_u_dim2 && k < boundaries_u_dim3) {
        int element = neighbor_ids[k];
        int side = neighbor_sides[k];

        // Indexing logic depends on how arrays are laid out in memory
        int idx_boundaries_u1 = j * boundaries_u_dim3 + k;
        int idx_boundaries_u2 =
            1 * boundaries_u_dim2 * boundaries_u_dim3 + j * boundaries_u_dim3 + k;
        int idx_u1 = j * u_dim2 * u_dim3 + (u_dim2 - 1) * u_dim3 + element - 1;
        int idx_u2 = j * u_dim2 * u_dim3 + element - 1;

        boundaries_u[idx_boundaries_u1] = (side == 1) ? u[idx_u1] : 0.0f;
        boundaries_u[idx_boundaries_u2] = (side != 1) ? u[idx_u2] : 0.0f;
    }
}

// CUDA kernel for getting last and first indices
__global__ void last_first_indices_kernel(float *lasts, float *firsts,
                                          const float *n_boundaries_per_direction, int n) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < n) {
        for (int ii = 0; ii <= i; ++ii) {
            lasts[i] += n_boundaries_per_direction[ii];
        }
        firsts[i] = lasts[i] - n_boundaries_per_direction[i] + 1;
    }
}

// CUDA kernel for calculating boundary fluxes on direction 1, 2
/* __global__ void boundary_flux_kernel(float *surface_flux_values, float *boundaries_u,
                                     float *node_coordinates, float t, int *boundary_arr,
                                     int *indices_arr, int *neighbor_ids, int *neighbor_sides,
                                     int *orientations, ConditionTuple boundary_conditions,
                                     AbstractEquations equations, int length_boundary_arr,
                                     int size_surface_flux_values) {

    int k = blockIdx.x * blockDim.x + threadIdx.x;

    if (k < length_boundary_arr) {
        int boundary = boundary_arr[k];
        int direction = (indices_arr[0] <= boundary) + (indices_arr[1] <= boundary);

        int neighbor = neighbor_ids[boundary];
        int side = neighbor_sides[boundary];
        int orientation = orientations[boundary];

        float *u_ll, *u_rr;
        get_surface_node_vars(boundaries_u, equations, boundary, u_ll,
                              u_rr); // TODO: `get_surface_node_vars`
        float *u_inner, *x;
        u_inner = (side == 1) ? u_ll : u_rr;
        x = get_node_coords(node_coordinates, equations, boundary);

        float *boundary_flux_node = boundary_stable_helper(
            boundary_conditions, u_inner, orientation, direction, x, t, surface_flux, equations);

        for (int ii = 0; ii < size_surface_flux_values; ++ii) {
            surface_flux_values[ii * direction + neighbor] = boundary_flux_node[ii];
        }
    }
} */

// Launch CUDA kernels to calculate boundary fluxes

__global__ void surface_integral_kernel(float *du, float *factor_arr, float *surface_flux_values,
                                        int du_dim1, int du_dim2, int du_dim3) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.z * blockDim.z + threadIdx.z;

    // Calculate a linear index for a 3D array given its dimensions and indices
    auto idx = [=](int a, int b, int c) { return c + b * du_dim1 + a * du_dim1 * du_dim2; };

    if (i < du_dim1 && j < du_dim2 && k < du_dim3) {
        if (j == 0) {
            du[idx(i, j, k)] -= surface_flux_values[idx(i, 0, k)] * factor_arr[0];
        }
        if (j == du_dim2 - 1) {
            du[idx(i, j, k)] += surface_flux_values[idx(i, 1, k)] * factor_arr[1];
        }
    }
}

// Launch CUDA kernel to calculate surface integrals

// CUDA kernel for applying inverse Jacobian
__global__ void jacobian_kernel(float *du, float *inverse_jacobian, int du_dim1, int du_dim2,
                                int du_dim3) {

    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.z * blockDim.z + threadIdx.z;

    // Calculate a linear index for a 3D array given its dimensions and indices
    auto idx = [=](int a, int b, int c) { return c + b * du_dim1 + a * du_dim1 * du_dim2; };

    if (i < du_dim1 && j < du_dim2 && k < du_dim3) {
        du[idx(i, j, k)] *= -inverse_jacobian[k];
    }
}

// Launch CUDA kernel to apply Jacobian to reference element

//
__global__ void source_terms_kernel(float *du, float *u, float *node_coordinates, float t,
                                    int du_dim1, int du_dim2, int du_dim3,
                                    AbstractEquations equations) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int k = blockIdx.y * blockDim.y + threadIdx.y;

    // Calculate a linear index for a 3D array given its dimensions and indices.
    auto idx = [=](int a, int b, int c) { return c + b * du_dim1 + a * du_dim1 * du_dim2; };

    if (j < du_dim2 && k < du_dim3) {
        float *u_local, *x_local;

        get_nodes_vars(u_local, equations, j, k);  // TODO: `get_nodes_vars`
        get_node_coords(x_local, equations, j, k); // TODO: `get_node_coords`

        float *source_terms_node;
        source_terms(u_local, x_local, t, source_terms_node);

        for (int ii = 0; ii < du_dim1; ++ii) {
            du[idx(ii, j, k)] += source_terms_node[ii];
        }
    }
}

// Launch CUDA kernel to calculate source terms

// For tests
// --------------------------------------------------

// ... [The provided functions here] ...

// This function initializes the GPU random number generator
void createRandomArrays(float *&flux_arr, float *&derivative_dhat, int width, int height,
                        int depth) {
    size_t flux_size = width * height * depth * sizeof(float);
    size_t derivative_size = width * height * sizeof(float);

    float *host_flux_arr = new float[width * height * depth];
    float *host_derivative_dhat = new float[width * height];

    // Generate random floats on host for flux_arr
    for (int i = 0; i < width * height * depth; i++) {
        host_flux_arr[i] = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    }

    // Generate random floats on host for derivative_dhat
    for (int i = 0; i < width * height; i++) {
        host_derivative_dhat[i] = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    }

    // Allocate GPU memory
    cudaMalloc((void **)&flux_arr, flux_size);
    cudaMalloc((void **)&derivative_dhat, derivative_size);

    // Copy random data from host to GPU
    cudaMemcpy(flux_arr, host_flux_arr, flux_size, cudaMemcpyHostToDevice);
    cudaMemcpy(derivative_dhat, host_derivative_dhat, derivative_size, cudaMemcpyHostToDevice);

    // Clean up host memory
    delete[] host_flux_arr;
    delete[] host_derivative_dhat;
}

// Main test function is moved to the main file