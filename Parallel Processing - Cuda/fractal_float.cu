/*
Fractal code for CS 4380 / CS 5351

Copyright (c) 2019 Texas State University. All rights reserved.

Redistribution in source or binary form, with or without modification,
is *not* permitted. Use in source and binary forms, with or without
modification, is only permitted for academic use in CS 4380 or CS 5351
at Texas State University.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Author: Martin Burtscher
*/

#include <cstdlib>
#include <cstdio>
#include <cmath>
#include <sys/time.h>
#include "cs43805351.h"
#include <cuda.h>

static const int ThreadsPerBlock = 512;

static void CheckCuda()
{
	cudaError_t e;
	cudaDeviceSynchronize();
	if (cudaSuccess != (e = cudaGetLastError())) {
		fprintf(stderr, "CUDA error %d: %s\n", e, cudaGetErrorString(e));
		exit(-1);
	}
}

static __global__ void fractal(const int width, const int frames, unsigned char* const pic)
{
  const float Delta = 0.006f;
  const float xMid = 0.232997f;
  const float yMid = 0.550325f;
  const int idx = threadIdx.x + blockIdx.x * blockDim.x;
  // compute frames
  const int col = idx % width;
  const int row = (idx / width) % width;
  const int frame = idx / (width * width);
  const float delta = Delta * pow(0.985f, frame);
  const float xMin = xMid - delta;
  const float yMin = yMid - delta;
  const float dw = 2.0f * delta / width;
  const float cy = yMin + row * dw;
  const float cx = xMin + col * dw;
  float x = cx;
  float y = cy;
  int depth = 256;
  float x2, y2;
  do {
     x2 = x * x;
     y2 = y * y;
     y = 2 * x * y + cy;
     x = x2 - y2 + cx;
     depth--;
     } while ((depth > 0) && ((x2 + y2) < 5.0f));
  pic[frame * width * width + row * width + col] = (unsigned char)depth;
      
    
}

int main(int argc, char *argv[])
{
  printf("Fractal v1.8\n");

  // check command line
  if (argc != 3) {fprintf(stderr, "USAGE: %s frame_width num_frames\n", argv[0]); exit(-1);}
  const int width = atoi(argv[1]);
  if (width < 10) {fprintf(stderr, "ERROR: frame_width must be at least 10\n"); exit(-1);}
  const int frames = atoi(argv[2]);
  if (frames < 1) {fprintf(stderr, "ERROR: num_frames must be at least 1\n"); exit(-1);}
  printf("frames: %d\n", frames);
  printf("width: %d\n", width);

  // allocate picture array
  unsigned char* pic = new unsigned char [frames * width * width];
  const int size = frames * width * width * sizeof(char);
  unsigned char* d_pic;
  cudaMalloc((void **)&d_pic, size);

  // start time
  timeval start, end;
  gettimeofday(&start, NULL);

  // launch GPU kernel
  fractal<<<(frames*width*width + ThreadsPerBlock - 1) / ThreadsPerBlock, ThreadsPerBlock>>>(width, frames, d_pic);
  cudaDeviceSynchronize();

  // end time
  gettimeofday(&end, NULL);
  const float runtime = end.tv_sec - start.tv_sec + (end.tv_usec - start.tv_usec) / 1000000.0f;
  printf("compute time: %.4f s\n", runtime);
  CheckCuda();

  // copy result back to host
  if (cudaSuccess != cudaMemcpy(pic, d_pic, size, cudaMemcpyDeviceToHost)) { fprintf(stderr, "copying from device failed\n"); exit(-1); }

  // write result to BMP files
  if ((width <= 256) && (frames <= 100)) {
    for (int frame = 0; frame < frames; frame++) {
      char name[32];
      sprintf(name, "fractal%d.bmp", frame + 1000);
      writeBMP(width, width, &pic[frame * width * width], name);
    }
  }

  delete [] pic;
  cudaFree(d_pic);
  return 0;
}

