#!/bin/bash
#SBATCH -J exatensor_test
#SBATCH -o job_%j.out
#SBATCH -e job_%j.err
#SBATCH -t 00:10:00
#SBATCH -p batch
#SBATCH -N 2

echo "Starting job $SLURM_JOB_ID at `date`"

source ${SLURM_SUBMIT_DIR}/../modules_frontier
module list

echo ${SLURM_SUBMIT_DIR}
echo ${SLURM_JOBID}
echo ${SLURM_JOB_NUM_NODES}
echo ${SLURM_JOB_NAME}
echo ${SLURM_NODELIST}
echo ${MEMBERWORK}

#ExaTENSOR specific:
export QF_PATH=${SLURM_SUBMIT_DIR}/..
export QF_NUM_PROCS=8             #total number of MPI processes
export QF_PROCS_PER_NODE=4        #number of MPI processes per node
export QF_CORES_PER_PROCESS=4     #number of physical CPU cores per MPI process (no less than 1)
export QF_MEM_PER_PROCESS=10000   #host RAM memory limit per MPI process in MB
export QF_NVMEM_PER_PROCESS=0     #non-volatile memory limit per MPI process in MB
export QF_HOST_BUFFER_SIZE=15000  #host buffer size per MPI process in MB (less than QF_MEM_PER_PROCESS!)
#export QF_GPUS_PER_PROCESS=0      #number of discrete NVIDIA GPUs per MPI process (optional)
#export QF_MICS_PER_PROCESS=0      #number of discrete Intel Xeon Phis per MPI process (optional)
export QF_AMDS_PER_PROCESS=1      #number of discrete AMD GPUs per MPI process (optional)
export QF_NUM_THREADS=${SLURM_CPUS_PER_TASK}          #initial number of CPU threads per MPI process (irrelevant)

# OpenMP environment
export OMP_NUM_THREADS=$QF_NUM_THREADS     #initial number of OpenMP threads per MPI process (=QF_NUM_THREADS)
#export OMP_DYNAMIC=false                   #no OpenMP dynamic threading
#export OMP_NESTED=true                     #OpenMP nested parallelism is mandatory
#export OMP_MAX_ACTIVE_LEVELS=3             #max number of OpenMP nesting levels (at least 3)
#export OMP_THREAD_LIMIT=256                #max total number of OpenMP threads per process
#export OMP_WAIT_POLICY=PASSIVE             #idle thread behavior
#export OMP_PROC_BIND="close,spread,spread" #nest1: Functional threads (DSVU)
export OMP_PROC_BIND=close
export OMP_PLACES_DEFAULT=cores
export OMP_PLACES=$OMP_PLACES_DEFAULT
export OMP_STACKSIZE=200M                  #stack size needed to avoid segmentation fault

#Cray/MPICH specific:
export MPICH_GPU_SUPPORT_ENABLED=1
#export MPICH_GPU_MANAGED_MEMORY_SUPPORT_ENABLED=1
export MPICH_OFI_NIC_POLICY=NUMA
export CRAY_OMP_CHECK_AFFINITY=TRUE         #CRAY: Show thread placement
export MPICH_MAX_THREAD_SAFETY=multiple      #CRAY: Required for MPI asynchronous progress
#export MPICH_NEMESIS_ASYNC_PROGRESS="MC"     #CRAY: Activate MPI asynchronous progress thread {"SC","MC"}
#export MPICH_RMA_OVER_DMAPP=1               #CRAY: DMAPP backend for CRAY-MPICH
#export MPICH_GNI_ASYNC_PROGRESS_TIMEOUT=0   #CRAY:
#export MPICH_GNI_MALLOC_FALLBACK=enabled    #CRAY:
#export MPICH_ALLOC_MEM_HUGE_PAGES=1         #CRAY: Huge pages
#export MPICH_ALLOC_MEM_HUGEPG_SZ=2M         #CRAY: Huge page size
#export _DMAPPI_NDREG_ENTRIES=16384          #CRAY: Max number of entries in UDREG memory registration cache
#export MPICH_GNI_MEM_DEBUG_FNAME=MPICH.memdebug
#export MPICH_RANK_REORDER_DISPLAY=1

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:$LD_LIBRARY_PATH

# Change directory to user scratch space (GPFS)
export temp_dir=${MEMBERWORK}/chm191/${SLURM_JOB_NAME}_${SLURM_JOBID}
echo ${temp_dir}
mkdir ${temp_dir}
cd ${temp_dir}

#try different settings t fix
#export MPI4PY_RC_RECV_MPROBE='False'
#export MPICH_SMP_SINGLE_COPY_MODE=NONE
#export PICH_GPU_IPC_ENABLED=0
#export MPICH_OFI_USE_PROVIDER="tcp;ofi_rxm"
#export MPICH_OFI_USE_PROVIDER="tcp"
#export FI_MR_CACHE_MONITOR=memhooks
#export FI_CXI_RX_MATCH_MODE=software
#export MPICH_OFI_NIC_POLICY=GPU
#export MPICH_OFI_NIC_POLICY=NUMA

#additional printing
#export MPICH_OFI_VERBOSE=1
export MPICH_OFI_NIC_VERBOSE=1
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
#export AMD_LOG_LEVEL=1
#export CRAY_ACC_DEBUG=1
#export GOMP_DEBUG=1                   #GNU OpenMP debugging
#export LOMP_DEBUG=1                   #IBM XL OpenMP debugging
export OMP_DISPLAY_ENV=VERBOSE        #display OpenMP environment variables

cp ${SLURM_SUBMIT_DIR}/../Qforce.x .

ulimit -c unlimited
ulimit -s unlimited

time srun -N${SLURM_NNODES} -n${SLURM_NTASKS} -c${OMP_NUM_THREADS} --cpu-bind=threads --threads-per-core=1 -m block:cyclic --gpus-per-node=4 --gpu-bind=closest  ./Qforce.x >& qforce.output


echo "            OMP_NUM_THREADS=${OMP_NUM_THREADS}"
echo "      MPICH_GPU_IPC_ENABLED=${MPICH_GPU_IPC_ENABLED}"
echo " MPICH_SMP_SINGLE_COPY_MODE=${MPICH_SMP_SINGLE_COPY_MODE}"
echo "     MPICH_OFI_USE_PROVIDER=${MPICH_OFI_USE_PROVIDER}"
echo "       ROCR_VISIBLE_DEVICES=${ROCR_VISIBLE_DEVICES}"

export out_dir=${SLURM_SUBMIT_DIR}/output_${SLURM_JOB_NAME}_${SLURM_JOBID}
mkdir ${out_dir}
mv * ${out_dir}
cd ${out_dir}
rm Qforce.x

fi_info

echo "... finished job $SLURM_JOB_ID at `date`"
