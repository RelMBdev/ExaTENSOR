#!/bin/bash
#
#SBATCH -J dirac-test
#SBATCH --output=info.o%j # Name of stdout output file
#SBATCH --error=info.e%j  # Name of stderr error file
#SBATCH --partition=small-g
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=20G
#SBATCH --gres=gpu:8
##SBATCH --hint=nomultithread

echo "Starting job $SLURM_JOB_ID at `date`"

ulimit -c unlimited
ulimit -s unlimited

#load necessary modules
module purge
module load LUMI/22.08
module load partition/G
module load buildtools/22.08
module load PrgEnv-gnu
#module load gcc/12.2.0
#module load amd-mixed
#module load cray-mpich
module load cray-libsci
module load cray-libsci_acc
module load cray-python
module load cray-hdf5-parallel
module load craype-x86-trento
module load rocm
module load craype-accel-amd-gfx90a
module load craype-hugepages2M

# add system information
export WRAP=WRAP
export TOOLKIT=GNU
export MPILIB=MPICH
export PATH_MPICH=${CRAY_MPICH_PREFIX}
export BUILD_TYPE=OPT
export BLASLIB=NONE
export PATH_BLAS_LIBSCI=${CRAY_LIBSCI_PREFIX_DIR}/lib
export MATH_ROOT=${CRAY_LIBSCI_PREFIX_DIR}
export MATH_ROOT=${CRAY_LIBSCI_PREFIX_DIR}
export WITH_LAPACK=NO

export EXA_OS=LINUX
export GPU_CUDA=CUDA
export GPU_SM_ARCH=90
export USE_HIP=YES
export PATH_ROCM=${ROCM_PATH}

#ExaTENSOR specific:
export QF_PATH=${SLURM_SUBMIT_DIR}/../bin/
#export QF_NUM_PROCS=4             #total number of MPI processes
#export QF_PROCS_PER_NODE=1        #number of MPI processes per logical node (logical nodes are created by node resource isolation)
#export QF_CORES_PER_PROCESS=1     #number of physical CPU cores per MPI process (no less than 1)
#export QF_MEM_PER_PROCESS=1024    #host RAM memory limit per MPI process in MB
#export QF_NVMEM_PER_PROCESS=0     #non-volatile memory limit per MPI process in MB
#export QF_HOST_BUFFER_SIZE=1024   #host buffer size per MPI process in MB (must be less than QF_MEM_PER_PROCESS)
#export QF_GPUS_PER_PROCESS=1      #number of discrete NVIDIA GPU's per MPI process (optional)
#export QF_MICS_PER_PROCESS=0      #number of discrete Intel Xeon Phi's per MPI process (optional)
#export QF_AMDS_PER_PROCESS=0      #number of discrete AMD GPU's per MPI process (optional)
export QF_NUM_THREADS=$SLURM_CPUS_PER_TASK #initial number of CPU threads per MPI process (irrelevant, keep it 8)

#OpenMP generic:
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK #initial number of OpenMP threads per MPI process
#export OMP_NUM_THREADS=1
#export OMP_DYNAMIC=false               #no OpenMP dynamic threading
#export OMP_NESTED=true                 #OpenMP nested parallelism is mandatory
#export OMP_MAX_ACTIVE_LEVELS=3         #max number of OpenMP nesting levels (at least 3)
#export OMP_THREAD_LIMIT=256            #max total number of OpenMP threads per process
#export OMP_WAIT_POLICY=PASSIVE         #idle thread behavior
export OMP_STACKSIZE=200M             #stack size per thread
export OMP_DISPLAY_ENV=VERBOSE        #display OpenMP environment variables
#export GOMP_DEBUG=1                   #GNU OpenMP debugging
#export LOMP_DEBUG=1                   #IBM XL OpenMP debugging

#OpenMP thread binding:
export OMP_PLACES_DEFAULT=threads                                      #default thread binding to CPU logical cores
#export OMP_PLACES=$OMP_PLACES_DEFAULT
export OMP_PLACES=cores
#export OMP_PROC_BIND="close,spread,spread" #nesting
export OMP_PROC_BIND=close

#Cray/MPICH specific:
#export CRAY_OMP_CHECK_AFFINITY=TRUE         #CRAY: Show thread placement
#export MPICH_MAX_THREAD_SAFETY=multiple      #CRAY: Required for MPI asynchronous progress
#export MPICH_NEMESIS_ASYNC_PROGRESS="MC"     #CRAY: Activate MPI asynchronous progress thread {"SC","MC"}
#export MPICH_RMA_OVER_DMAPP=1               #CRAY: DMAPP backend for CRAY-MPICH
#export MPICH_GNI_ASYNC_PROGRESS_TIMEOUT=0   #CRAY:
#export MPICH_GNI_MALLOC_FALLBACK=enabled    #CRAY:
#export MPICH_ALLOC_MEM_HUGE_PAGES=1         #CRAY: Huge pages
#export MPICH_ALLOC_MEM_HUGEPG_SZ=2M         #CRAY: Huge page size
#export _DMAPPI_NDREG_ENTRIES=16384          #CRAY: Max number of entries in UDREG memory registration cache
#export MPICH_ENV_DISPLAY=1
#export MPICH_GNI_MEM_DEBUG_FNAME=MPICH.memdebug
#export MPICH_RANK_REORDER_DISPLAY=1
#export MPICH_GPU_SUPPORT_ENABLED=1
#export MPICH_OFI_NIC_POLICY=NUMA

cat << EOF > select_gpu
#!/bin/bash

export ROCR_VISIBLE_DEVICES=\$SLURM_LOCALID
exec \$*
EOF

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:$LD_LIBRARY_PATH

chmod +x ./select_gpu

rm core.* *.tmp *.log *.out *.x 
cp $QF_PATH/test_talsh.x ./

#time srun -N ${SLURM_NNODES} -n ${SLURM_NTASKS} -c ${OMP_NUM_THREADS} ./select_gpu ./Qforce.x >& qforce.log

echo "to do: time srun -N ${SLURM_NNODES} -n ${SLURM_NTASKS} -c ${OMP_NUM_THREADS} ./select_gpu ./test_talsh.x >& test_talsh.output"
time srun -N ${SLURM_NNODES} -n ${SLURM_NTASKS} -c ${OMP_NUM_THREADS} ./select_gpu ./test_talsh.x >& test_talsh.output

rm test_talsh.x 

echo "... finished job $SLURM_JOB_ID at `date`"
