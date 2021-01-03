#include "GpuIdwGlobalMemory.cuh"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

static void handleCudaError(const cudaError_t error, const char* file, const int line) {
	if (error == cudaSuccess) return;

	fmt::print("{} in {} at line {}\n", cudaGetErrorString(error), file, line);
	exit(EXIT_FAILURE);
}

#define CHECK_ERROR( error ) ( handleCudaError( error, __FILE__, __LINE__ ) )

namespace
{
	__device__ double computeWiGpu(const int ax, const int ay, const int bx, const int by, const double pParam) {
		const float dist = sqrtf((ax - bx) * (ax - bx) + (ay - by) * (ay - by));
		return 1 / powf(dist, pParam);
	}

	__global__ void firstKernel(uint8_t* bitmap, const int* anchorPoints, const int anchorPointsCount, const double pParam, const int width, const int height) {

		const int xStart = blockIdx.x * blockDim.x + threadIdx.x;
		const int yStart = blockIdx.y * blockDim.y + threadIdx.y;

		//fill its own chunk
		for (int h = yStart; h < yStart + blockDim.y && h < height; ++h) {
			for (int w = xStart; w < xStart + blockDim.x && w < width; ++w) {
				double wiSum = 0;
				double outputSum = 0;

				for (int i = 0; i < anchorPointsCount; i++) {
					const double wi = computeWiGpu(w, h, anchorPoints[i * 3], anchorPoints[i * 3 + 1], pParam);
					wiSum += wi;
					outputSum += wi * anchorPoints[i * 3 + 2];
				}
				outputSum /= wiSum;

				bitmap[3 * (h * width + w) + 0] = static_cast<uint8_t>(outputSum);
				bitmap[3 * (h * width + w) + 1] = static_cast<uint8_t>(outputSum);
				bitmap[3 * (h * width + w) + 2] = static_cast<uint8_t>(outputSum);
			}
		}
	}
}


void GpuIdwGlobalMemory::refreshInnerGpu(const double pParam) {
	dim3 blocks(768 / 16, 768 / 16);
	dim3 threads(16, 16);

	firstKernel <<< blocks, threads >>>(bitmapGpu, anchorsGpu, anchorsGpuCurrentCount, pParam, width, height);
	CHECK_ERROR(cudaGetLastError());
}
