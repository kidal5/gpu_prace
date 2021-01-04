#include "GpuIdwBase.cuh"

static void handleCudaError(const cudaError_t error, const char* file, const int line) {
	if (error == cudaSuccess) return;

	fmt::print("{} in {} at line {}\n", cudaGetErrorString(error), file, line);
	exit(EXIT_FAILURE);
}

#define CHECK_ERROR( error ) ( handleCudaError( error, __FILE__, __LINE__ ) )


GpuIdwBase::GpuIdwBase(const int _width, const int _height, const std::string& _methodName) : CpuIdwBase(_width, _height, _methodName) {

	CHECK_ERROR(cudaMalloc(reinterpret_cast<void**>(&anchorsGpu), anchorsGpuBytes));
}

GpuIdwBase::~GpuIdwBase() {

	if (anchorsGpu) 
		CHECK_ERROR(cudaFree(anchorsGpu));
}

uint8_t* GpuIdwBase::getBitmapGreyscaleCpu() {

	if (!lastGreyscaleVersionOnCpu){
		downloadGreyscaleBitmap();
		lastGreyscaleVersionOnCpu = true;
	}

	return bitmapGreyscaleCpu;
}

uint32_t* GpuIdwBase::getBitmapColorCpu() {
	if (!lastColorVersionOnCpu) {
		downloadColorBitmap();
		lastColorVersionOnCpu = true;
	}

	return bitmapColorCpu;
}


void GpuIdwBase::refreshInnerGreyscale(DataManager& manager) {
	lastGreyscaleVersionOnCpu = false;
	copyAnchorsToGpu(manager.getAnchorPoints());
	refreshInnerGreyscaleGpu(manager.getPParam());
}

void GpuIdwBase::refreshInnerColor(const Palette& p) {
	lastColorVersionOnCpu = false;
	refreshInnerColorGpu(p);
}

void GpuIdwBase::copyAnchorsToGpu(const std::vector<P2>& anchorPoints) {

	if (anchorPoints.size() > anchorsGpuMaxCount) {
		//free memory
		if (anchorsGpu) CHECK_ERROR(cudaFree(anchorsGpu));

		anchorsGpuMaxCount = anchorsGpuMaxCount * 2;
		anchorsGpuBytes = anchorsGpuMaxCount * 3 * sizeof(int);

		//create bigger memory
		CHECK_ERROR(cudaMalloc(reinterpret_cast<void**>(&anchorsGpu), anchorsGpuBytes));
	}

	anchorsGpuCurrentCount = anchorPoints.size();

	//i should be able to just read vector's data as ints ...

	const auto* rawPointer = reinterpret_cast<const int*>(anchorPoints.data());

	const auto err = cudaMemcpy(anchorsGpu, rawPointer, anchorsGpuBytes, cudaMemcpyHostToDevice);
	CHECK_ERROR(err);
}
