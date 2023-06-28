#!/bin/bash
#SBATCH -J exatensor_test
#SBATCH -o job_%j.out
#SBATCH -e job_%j.err
#SBATCH -t 00:10:00
#SBATCH -p batch
#SBATCH -N 2

date

echo ${SLURM_SUBMIT_DIR}
echo ${SLURM_JOBID}
echo ${SLURM_JOB_NUM_NODES}
echo ${SLURM_JOB_NAME}
echo ${SLURM_NODELIST}
echo ${MEMBERWORK}

source ${SLURM_SUBMIT_DIR}/../modules
module list

# Change directory to user scratch space (GPFS)
export temp_dir=${MEMBERWORK}/chm191/${SLURM_JOB_NAME}_${SLURM_JOBID}
echo ${temp_dir}
mkdir ${temp_dir}
cd ${temp_dir}


cp ${SLURM_SUBMIT_DIR}/../Qforce.x .

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


srun -N2 -n8 -c4 --cpu-bind=threads --threads-per-core=1 -m block:cyclic --ntasks-per-node=4 --gpus-per-node=4 --gpu-bind=closest ./Qforce.x > qforce.output


echo "      MPI4PY_RC_RECV_MPROBE=${MPI4PY_RC_RECV_MPROBE}"
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

