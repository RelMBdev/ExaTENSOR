#!/bin/bash

ml purge
ml intel/2019a

export TOOLKIT=INTEL
export BUILD_TYPE=OPT
export MPILIB=MPICH
export PATH_MPICH=/apps/all/impi/2018.4.274-iccifort-2019.1.144-GCC-8.2.0-2.31.1
export PATH_MPICH_INC=${PATH_MPICH}/include64
export PATH_MPICH_LIB=${PATH_MPICH}/lib64
export PATH_MPICH_BIN=${PATH_MPICH}/bin64
export BLASLIB=MKL
export PATH_BLAS_MKL=/apps/all/imkl/2019.1.144-iimpi-2019a/mkl/lib/intel64
export PATH_BLAS_MKL_DEP=/apps/all/imkl/2019.1.144-iimpi-2019a/lib/intel64
export PATH_BLAS_MKL_INC=/apps/all/imkl/2019.1.144-iimpi-2019a/mkl/include
export GPU_CUDA=NOCUDA
#export GPU_CUDA=CUDA
#export GPU_SM_ARCH=80
export EXA_OS=LINUX
export WITH_CUTT=NO
#export EXA_TALSH_ONLY=YES

ulimit -s unlimited

make clean 
make

