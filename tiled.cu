#define FP float

#include <stdio.h>
#include <cuda.h>
#include <stdlib.h>
#include <math.h>

#define BLOCK_WIDTH 16

// N rows (height)
// M columns (width)

void globalDebugMatrix(int m, int n, FP *matrix){
  for(int i = 0; i < n; i++){
    for(int j = 0; j < m; j++){
      printf("%e ", matrix[m * i + j]);
    }

    printf("\n");
  }
}

__device__ void debugMatrix(int m, int n, FP *matrix){
  for(int i = 0; i < n; i++){
    for(int j = 0; j < m; j++){
      printf("%e ", matrix[m * i + j]);
    }

    printf("\n");
  }
}

__global__ void gpu_matrixmult(FP *a,FP *b, FP *c, int n, int m, int p) {

  // int col = threadIdx.x + blockDim.x * blockIdx.x;
  // int row = threadIdx.y + blockDim.y * blockIdx.y;

  // int indexb = col;
  // int index = row * m + col;
  // 
  // if(col < m && row < n) {
  //   c[index] = 0.;
  //   for (int indexa = row*p; indexa < (row*p + p); indexa++, indexb+=m) 
  //     c[index] += a[indexa]*b[indexb];
  // }

  if(blockDim.x != blockDim.y){
    printf("Error - block is not square!\n");
    return;
  }

  int debug = false;

  int block_width = blockDim.x;
  
  int threadx = threadIdx.x;
  int thready = threadIdx.y;
  int blockx = blockIdx.x;
  int blocky = blockIdx.y;

  if(threadx == 0 && thready == 0 && blockx == 1 && blocky == 0) debug = false;
  
  int xcoord = blockx*block_width + threadx;
  int ycoord = blocky*block_width + thready;
  

  if(xcoord > m || ycoord > n){
    printf("We're not needed!\n"); // tbh surprised we can call printf from device
    return;
  }
  

  // for now just do perfect matches
  if(p % block_width > 0.0)
    printf("WARNING: matrix p dimension is not a perfect multiple of block width!\n");
  if(m % block_width > 0.0)
    printf("WARNING: matrix m dimension is not a perfect multiple of block width!\n");
  if(n % block_width > 0.0)
    printf("WARNING: matrix n dimension is not a perfect multiple of block width!\n");
    
  // extern __shared__ FP As[];
  // FP *Bs = As + (block_width * block_width * sizeof(FP));

  __shared__ FP As[BLOCK_WIDTH * BLOCK_WIDTH * sizeof(FP)];
  __shared__ FP Bs[BLOCK_WIDTH * BLOCK_WIDTH * sizeof(FP)];

  FP c_value = 0.;
  for(int i = 0; i < (p / block_width); i++){

    if(debug){
      printf("On iteration %d\n", i);
    }
    

    // __shared__ FP *As = cudaMalloc(sizeof(FP) * block_width * block_width);
    // __shared__ FP *Bs = cudaMalloc(sizeof(FP) * block_width * block_width);

    int a_y = blocky*block_width + thready;
    int a_x = i*block_width + threadx;

    int b_y = i*block_width + thready;
    int b_x = blockx*block_width + threadx;

    // each thread computes one matrix value
    As[block_width * thready + threadx] = a[p * a_y + a_x];
    Bs[block_width * thready + threadx] = b[m * b_y + b_x];
    if(debug)printf("My copied vals in a and b are %e %e\n", As[block_width * thready + threadx], Bs[block_width * thready + threadx]);

    if(debug){
      As[block_width * thready + threadx] = a[p * a_y + a_x];
      Bs[block_width * thready + threadx] = b[m * b_y + b_x];
      printf("My copied vals in a and b are %e %e\n", As[block_width * thready + threadx], Bs[block_width * thready + threadx]);
    }
    
    // wait for all to finish computing As, Bs
    __syncthreads();
    
    if(debug){
      printf("My ax, ay, bx, by are %d %d %d %d\n", a_x, a_y, b_x, b_y);
      printf("My copied vals in a and b are %e %e\n", As[block_width * thready + threadx], Bs[block_width * thready + threadx]);
      printf("As:\n");
      debugMatrix(block_width, block_width, As);
      printf("Bs:\n");
      debugMatrix(block_width, block_width, Bs);
      printf("\n\n");
    }


    for(int e = 0; e < block_width; e++){
      c_value += As[thready * block_width + e] * Bs[e * block_width + threadx];
    }

    // let other threads finish before computing next As, Bs
    __syncthreads();
  }

  c[m*ycoord + xcoord] = c_value;
}

void cpu_matrixmult(FP *a,FP *b, FP *c, int n, int m, int p) {
  // Taken directly from slides
  printf("Broken version first!\n");
  for(int k = 0; k < p; k++){
    for(int i = 0; i < n; i++){
      FP r = a[(i * p) + k];
      int cbase = i * m;
      int bbase = k * m;
      for(int j = 0; j < m; j++){
        c[cbase + j] -= r * b[bbase + j];
      }
    }
  }
}

int main(int argc, char *argv[]) {

  int i, j; // loop counters

  int gpucount = 0; // Count of available GPUs
  int gpunum = 0; // Device number to use
  int Grid_Dim = 1; //Grid dimension, x and y, square
  int Block_Dim = 1; //Block dimension, x and y, square

  int n, m, p; // matrix dimension
  FP *a,*b,*c;
  FP *dev_a, *dev_b, *dev_c;
  int size_a, size_b, size_c; // number of bytes in arrays

  cudaEvent_t start, stop; // using cuda events to measure time
  float elapsed_time_ms; // which is applicable for asynchronous code also
  cudaError_t errorcode;

  // --------------------SET PARAMETERS AND DATA -----------------------

  errorcode = cudaGetDeviceCount(&gpucount);
  if (errorcode == cudaErrorNoDevice) {
    printf("No GPUs are visible\n");
    exit(-1);
  }
  else {
     printf("Device count = %d\n",gpucount);
  }

  if ((argc<6) || (argc>7)) {
    printf("Usage: tiled <n> <m> <p> <block dim> <grid dim> [<dev num>]\n");
    exit (-1);
  }

  n = atoi(argv[1]);
  m = atoi(argv[2]);
  p = atoi(argv[3]);

  Block_Dim = atoi(argv[4]); // Square block
  if (Block_Dim*Block_Dim > 1024) {
    printf("Error, too many threads in block\n");
    exit (-1);
  }

  Grid_Dim = atoi(argv[5]); // Square grid
  if (Grid_Dim*Block_Dim < n) {
    printf("Error, number of threads in x/y dimensions less than number of array elements\n");
    exit (-1);
  }

  if (argc==7) {
    gpunum = atoi(argv[6]); // Device number
    if ((gpunum > 2) || (gpunum < 0)) {
      printf("Error, Device number must be 0, 1, or 2\n");
      exit (-1);
    }
  }
  cudaSetDevice(gpunum);
  printf("Using device %d\n",gpunum);
  
  printf("Matrix Dimension = %d %d %d\n",n, m, p);
  printf("Block_Dim = %d, Grid_Dim = %d\n",Block_Dim,Grid_Dim);

  dim3 Grid(Grid_Dim, Grid_Dim); //Grid structure
  dim3 Block(Block_Dim, Block_Dim); //Block structure

  size_a = n * p * sizeof(FP); // number of bytes in total in arrays
  size_b = m * p * sizeof(FP); // number of bytes in total in arrays
  size_c = m * n * sizeof(FP); // number of bytes in total in arrays

  a = (FP*) malloc(size_a); // dynamically allocated memory for arrays on host
  b = (FP*) malloc(size_b);
  c = (FP*) malloc(size_c); // results from GPU

  srand(12345);
  for(i=0;i < n;i++)
    for(j=0;j < p;j++) {
      a[i * p + j] = (FP) rand() / (FP) RAND_MAX;
      //       a[i * p + j] = (FP) i+j; // may be helpful for debugging
    }

  for(i=0;i < p;i++)
    for(j=0;j < m;j++) {
      b[i * m + j] = (FP) rand() / (FP) RAND_MAX;
      //      b[i * n + j] = (FP) i+j; // may be helpful for debugging
    }

  // printf("A:\n");
  // globalDebugMatrix(p, n, a);

  // printf("B:\n");
  // globalDebugMatrix(m, p, b);
  // ------------- COMPUTATION DONE ON GPU ----------------------------

  cudaMalloc((void**)&dev_a, size_a); // allocate memory on device
  cudaMalloc((void**)&dev_b, size_b);
  cudaMalloc((void**)&dev_c, size_c);

  cudaMemcpy(dev_a, a , size_a ,cudaMemcpyHostToDevice);
  cudaMemcpy(dev_b, b , size_b ,cudaMemcpyHostToDevice);

  cudaEventCreate(&start); // instrument code to measure start time
  cudaEventCreate(&stop);
  
  cudaEventRecord(start, 0);
  // cudaEventSynchronize(start); // not needed

  // gpu_matrixmult<<<Grid,Block>>>(dev_a,dev_b,dev_c,n,m,p);
  gpu_matrixmult<<<Grid,Block, 2*Block_Dim*Block_Dim*sizeof(FP)>>>(dev_a,dev_b,dev_c,n,m,p);
  printf("Allocating %d bytes total\n", 2*Block_Dim*Block_Dim*sizeof(FP));

  cudaEventRecord(stop, 0); // instrument code to measure end time
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&elapsed_time_ms, start, stop );

  cudaMemcpy(c,dev_c, size_c,cudaMemcpyDeviceToHost);

  printf("Time to calculate results on GPU: %f ms.\n", elapsed_time_ms); // exec. time

  // ------------- COMPUTATION DONE ON HOST CPU ----------------------------
  // DEBUGGING USE ONLY (AND FOR LIMITED NUMBERS OF TIMING RUNS)

  cudaEventRecord(start, 0); // use same timing
  // cudaEventSynchronize(start); // not needed


  cpu_matrixmult(a,b,c,n,m,p); // do calculation on host (NOTE: This computes the diff with GPU result.)

  cudaEventRecord(stop, 0); // instrument code to measue end time
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&elapsed_time_ms, start, stop );

  printf("Time to calculate results on CPU: %f ms.\n", elapsed_time_ms); // exec. time

// ------------------- check device creates correct results -----------------

  double error, sumc, ci;
  sumc = 0;
  for(i=0;i < m*n;i++) {
    ci = (double) c[i];
    sumc += ci*ci;
  }
  sumc = sqrt(sumc);
  error = sumc;
  printf("Total error between GPU and CPU: %e\n", error);

// -------------- clean up ---------------------------------------

  free(a);
  free(b);
  free(c);
  cudaFree(dev_a);
  cudaFree(dev_b);
  cudaFree(dev_c);

  cudaEventDestroy(start);
  cudaEventDestroy(stop);

  return 0;
}
