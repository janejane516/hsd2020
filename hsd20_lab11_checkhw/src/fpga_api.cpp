#include "fpga_api.h"
#include <cstdio>
#include <cstring>

#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define DATA_SIZE SIZE*(SIZE+1)*sizeof(float) // fpga bram data size

#define min(x,y) (((x)<(y))?(x):(y))

FPGA::FPGA(off_t data_addr, off_t api_addr)
{
    fd_ = open("/dev/mem", O_RDWR);
    data_ = static_cast<float*>(mmap(NULL, DATA_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd_, data_addr));
    api_ = static_cast<unsigned int*>(mmap(NULL, sizeof(unsigned int), PROT_READ|PROT_WRITE, MAP_SHARED,fd_, api_addr));
}

FPGA::~FPGA()
{
    munmap(data_, DATA_SIZE );
    munmap(api_, sizeof(unsigned int));
    close(fd_);
}

float* FPGA::matrix(void)
{
	return data_;
}

float* FPGA::vector(void)
{
	return data_ + SIZE*SIZE;
}

const float* __attribute__((optimize("O0"))) FPGA::run()
{
    *api_ = 0x5555;
    while(*api_ == 0x5555);

    return data_;    
}

// Test code for bitstream
void FPGA::largeMV(const float* large_mat, const float* input,
		float* output, int M, int N)
{
	float *vec = this->vector();
	float *mat = this->matrix();

	// 0) Initialize output vector	
	for (int i = 0; i < N; ++i)
		output[i] = 0;

	for (int i = 0; i < N; i += SIZE)
	{
		for (int j = 0; j < M; j += SIZE)
		{
			// 0) Initialize input vector
			int block_row = min(SIZE, N - i);
			int block_col = min(SIZE, M - j);

			// 1) Assign a vector
				  /* IMPLEMENT */

			memcpy(vec, input + j, sizeof(float)*block_col);
			memset(vec + block_col, 0, sizeof(float)*(SIZE - block_col));

			// 2) Assign a matrix
			/* IMPLEMENT */

			memset(mat, 0, SIZE * SIZE * sizeof(float));

			for (int row = 0; row < block_row; row++) {
				int curr = (i * M) + j + (M * row);
				memcpy(mat + SIZE * row, large_mat + curr, sizeof(float)*block_col);
			}
			
			// 3) Call a function `run() to execute MV multiplication
			const float* rst = this->run();

			// 4) Accumulate intermediate results
			for (int nn = 0; nn < block_row; ++nn) {
				output[i + nn] += rst[nn];
			}
		} 
	}
}
