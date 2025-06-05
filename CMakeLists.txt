# Example cmake command to build EXATENSOR
# -DEXATENSOR_GPU=ON
# (CUDA) -DEXATENSOR_GPU_ARCH=70 [-DWITH_CUTENSOR=ON -DCUTENSOR_ROOT=/opt/cutensor]
# (AMD) -DROCM_ROOT=$ROCM_PATH -DUSE_HIP=ON [-DEXATENSOR_GPU_ARCH=gfx908]
# (Optional) -DUSE_OPENMP=ON -DBUILD_TESTS=ON  -DEXATENSOR_FINE_TIMING=ON

cmake_minimum_required(VERSION 3.18.0 FATAL_ERROR)
project (EXATENSOR VERSION 0.1.0 LANGUAGES C CXX Fortran)

if(NOT CMAKE_BUILD_TYPE)
    set (CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_NO_SYSTEM_FROM_IMPORTED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ON)

option(USE_HIP OFF)
option(USE_OPENMP OFF)
option(LINUX_GNU_ASAN OFF)
option(BUILD_TESTS OFF)


#TODO:
#Cray, Clang compiler flags
# DF := -WF, when using IBM compilers
# HIP, ASAN_COMPILE

set(EXATENSOR_GPU_DEFS NO_GPU)

if (EXATENSOR_GPU)
	if(USE_HIP)
		set(EXATENSOR_GPU_DEFS USE_HIP)
		#TODO: check if ROCM_ROOT is valid
		list (APPEND CMAKE_PREFIX_PATH ${ROCM_ROOT} ${ROCM_ROOT}/hip ${ROCM_ROOT}/hipblas)
		if(EXATENSOR_GPU_ARCH)
			set(GPU_TARGETS ${EXATENSOR_GPU_ARCH} CACHE STRING "GPU targets to compile for")
		endif()
		find_package(hip REQUIRED)
		find_package(hipblas REQUIRED)
	else()
		set(EXATENSOR_GPU_DEFS "CUDA_ARCH=${EXATENSOR_GPU_ARCH}0")
		enable_language(CUDA)
		set(CMAKE_CUDA_STANDARD 11)
		set(CMAKE_CUDA_EXTENSIONS OFF)
		set(CMAKE_CUDA_STANDARD_REQUIRED ON)
		# set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)
		set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
		find_package(CUDAToolkit REQUIRED COMPONENTS cublas)
	endif()
endif()

if(WITH_CUTENSOR)
  list(APPEND EXATENSOR_GPU_DEFS USE_CUTENSOR)
endif()

if(EXATN_SERVICE)
  list(APPEND EXATENSOR_GPU_DEFS EXATN_SERVICE)
endif()

if(CMAKE_Fortran_COMPILER_ID STREQUAL "Intel")
  set(EXATENSOR_Fortran_FLAGS ${EXATENSOR_Fortran_FLAGS} -fpp -vec-threshold4 -mkl=parallel)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "PGI")
  set(EXATENSOR_Fortran_FLAGS ${EXATENSOR_Fortran_FLAGS} -Mcache_align -Mstandard -Mallocatable=03)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "XL")
  set(EXATENSOR_Fortran_FLAGS ${EXATENSOR_Fortran_FLAGS} -qpic=large)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Cray")
  set(EXATENSOR_Fortran_FLAGS ${EXATENSOR_FORTRAN_FLAGS} -hpic)
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "PGI")
  set(EXATENSOR_CXX_FLAGS ${EXATENSOR_CXX_FLAGS} -silent -w -Mnovect)
# elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Cray")
#   set(EXATENSOR_CXX_FLAGS ${EXATENSOR_CXX_FLAGS} -h)
endif()

if (NOT EXATENSOR_BLAS)
    set(NO_BLAS NO_BLAS)
endif()

set(EXATENSOR_CXX_COMPILE_DEFS ${EXATENSOR_GPU_DEFS} ${NO_BLAS} ${NO_OMP} NO_AMD NO_PHI LINUX)
set(EXATENSOR_Fortran_COMPILE_DEFS ${EXATENSOR_GPU_DEFS} ${NO_BLAS} ${NO_OMP} NO_AMD NO_PHI LINUX)

if (EXATENSOR_GPU AND NOT USE_HIP)
	set(EXATENSOR_INCLUDES ${CUDAToolkit_INCLUDE_DIRS})
	if(WITH_CUTENSOR)
		list(APPEND EXATENSOR_INCLUDES ${CUTENSOR_ROOT}/include)
	endif()
# else()
    # set(EXATENSOR_INCLUDES ${MPI_C_INCLUDE_PATH} ${MPI_Fortran_INCLUDE_PATH})
endif()

find_package(MPI)
if(MPI_FOUND)
    if(DEFINED CMAKE_Fortran_COMPILER_ID)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${MPI_COMPILE_FLAGS}")
        if(CMAKE_Fortran_COMPILER_ID MATCHES GNU)
            set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fallow-argument-mismatch")
    	endif()
    endif()
    if(DEFINED CMAKE_C_COMPILER_ID)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${MPI_COMPILE_FLAGS}")
    endif()
    if(DEFINED CMAKE_CXX_COMPILER_ID)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${MPI_COMPILE_FLAGS}")
    endif()
    include_directories(${MPI_INCLUDE_PATH})

    add_definitions(-DHAVE_MPI)
else()
    message(FATAL_ERROR "-- ExaTensor requires MPI, but CMake could not find any MPI installation, check $PATH")
endif()

# find_package(OPENMP REQUIRED)
find_package(OpenMP REQUIRED)
if(OPENMP_FOUND)
    add_definitions(-DHAVE_OPENMP)
    if(DEFINED CMAKE_C_COMPILER_ID)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    endif()
    if(DEFINED CMAKE_CXX_COMPILER_ID)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    endif()
    if(DEFINED CMAKE_Fortran_COMPILER_ID)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${OpenMP_Fortran_FLAGS}")
    endif()
else()
    message(FATAL_ERROR "-- ExaTensor requires OpenMP, but CMake could not find any OpenMP installation, check $PATH")
endif()

if(DEFINED CMAKE_Fortran_COMPILER_ID AND NOT DEFINED OpenMP_Fortran_FLAGS)
    # we do this in a pedestrian way because the Fortran support is relatively recent
    if(CMAKE_Fortran_COMPILER_ID MATCHES GNU)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -fopenmp")
    endif()
    if(CMAKE_Fortran_COMPILER_ID MATCHES Intel)
        if(WIN32)
            set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -Qopenmp")
        elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Intel" AND
               "${CMAKE_Fortran_COMPILER_VERSION}" VERSION_LESS "15.0.0.20140528")
            set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -openmp")
        else()
            set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -qopenmp")
        endif()
    endif()
    if(CMAKE_Fortran_COMPILER_ID MATCHES NVHPC)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -mp")
    endif()
    if(CMAKE_Fortran_COMPILER_ID MATCHES XL)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -qsmp=omp")
    endif()
    if(CMAKE_Fortran_COMPILER_ID MATCHES Cray)
        # do nothing in this case
    endif()
    set(OPENMP_FOUND TRUE)
endif()

set(EXATENSOR_FORTRAN_SOURCES
        DDSS/c2f_ifc.F90
        DDSS/distributed.F90
        DDSS/main.F90
        DDSS/pack_prim.F90
        DDSS/service_mpi.F90
        DDSS/test_pack_prim.F90
        DSVP/dsvp_base.F90
        GFC/dictionary.F90
        GFC/gfc_bank.F90
        GFC/gfc_base.F90
        GFC/gfc_dictionary.F90
        GFC/gfc_graph.F90
        GFC/gfc_hash_map.F90
        GFC/gfc_list.F90
        GFC/gfc_pri_queue.F90
        GFC/gfc_queue.F90
        GFC/gfc_range.F90
        GFC/gfc_stack.F90
        GFC/gfc_tree.F90
        GFC/gfc_vec_tree.F90
        GFC/gfc_vector.F90
        GFC/lists.F90
        GFC/main.F90
        GFC/multords.F90
        GFC/stack.F90
        INTERVIRT/exatensor.F90
        INTERVIRT/tavp_manager.F90
        INTERVIRT/tavp_worker.F90
        INTRAVIRT/hardware.F90
        INTRAVIRT/subspaces.F90
        INTRAVIRT/tensor_recursive.F90
        INTRAVIRT/test_intra.F90
        INTRAVIRT/virta.F90
        QFORCE/main.F90
        QFORCE/qforce.F90
        TALSH/combinatoric.F90
        TALSH/dil_basic.F90
        TALSH/main.F90
        TALSH/stsubs.F90
        TALSH/symm_index.F90
        TALSH/talshf.F90
        TALSH/tensor_algebra.F90
        TALSH/tensor_algebra_cpu.F90
        TALSH/tensor_algebra_cpu_phi.F90
        TALSH/tensor_dil_omp.F90
        TALSH/timers.F90
        UTILITY/parse_prim.F90
	)

set(EXATENSOR_CXX_SOURCES
        TALSH/talshxx.cpp
        TALSH/test.cpp
        TALSH/byte_packet.cpp
        TALSH/talsh_task.cpp
        TALSH/tensor_algebra_gpu.cpp
        TALSH/timer.cpp
        TALSH/talshc.cpp
        TALSH/tensor_algebra_gpu_nvidia.cpp
    )

if(USE_HIP)
	list(APPEND EXATENSOR_CXX_SOURCES TALSH/mem_manager.hip.cpp)
else()
	list(APPEND EXATENSOR_CXX_SOURCES TALSH/mem_manager.cpp)
endif()

if(EXATENSOR_GPU)
	set(EXATENSOR_CUDA_SOURCES TALSH/tensor_algebra_gpu_nvidia.cu)
	set(EXATENSOR_HIP_SOURCES TALSH/tensor_algebra_gpu_nvidia.hip.cu)
endif()

if(USE_HIP)
	configure_file(TALSH/tensor_algebra_gpu_nvidia.hip.cu ${PROJECT_SOURCE_DIR}/TALSH/tensor_algebra_gpu_nvidia.cpp COPYONLY)
	list(APPEND EXATENSOR_CXX_SOURCES TALSH/tensor_algebra_gpu_nvidia.cpp)
elseif(NOT EXATENSOR_GPU)
	configure_file(TALSH/tensor_algebra_gpu_nvidia.cu ${PROJECT_SOURCE_DIR}/TALSH/tensor_algebra_gpu_nvidia.cpp COPYONLY)
	list(APPEND EXATENSOR_CXX_SOURCES TALSH/tensor_algebra_gpu_nvidia.cpp)
endif()

if(EXATENSOR_GPU)
	set(EXATENSOR_CUDA_FLAGS  ${EXATENSOR_CUDA_FLAGS} -lineinfo -w -D_FORCE_INLINES -m64
		-Xptxas --warn-on-spills;-gencode arch=compute_${EXATENSOR_GPU_ARCH},code=sm_${EXATENSOR_GPU_ARCH}; -ccbin ${CMAKE_CXX_COMPILER})

	if(EXATENSOR_FINE_TIMING)
		list(APPEND EXATENSOR_CXX_COMPILE_DEFS GPU_FINE_TIMING)
		list(APPEND EXATENSOR_Fortran_COMPILE_DEFS GPU_FINE_TIMING)
	endif()
endif()

add_library(exatensor_cxx OBJECT ${EXATENSOR_CXX_SOURCES})
target_include_directories(exatensor_cxx PRIVATE ${EXATENSOR_INCLUDES})
target_compile_definitions(exatensor_cxx PRIVATE ${EXATENSOR_CXX_COMPILE_DEFS})
target_compile_options(exatensor_cxx PRIVATE ${EXATENSOR_CXX_FLAGS})
if(USE_HIP)
	target_link_libraries(exatensor_cxx PRIVATE hip::device)
endif()

if(EXATENSOR_GPU)
	add_library(exatensor_fort OBJECT ${EXATENSOR_FORTRAN_SOURCES})
	target_include_directories(exatensor_fort PRIVATE ${EXATENSOR_INCLUDES})
	target_compile_definitions(exatensor_fort PRIVATE ${EXATENSOR_Fortran_COMPILE_DEFS})
	target_compile_options(exatensor_fort PRIVATE ${EXATENSOR_Fortran_FLAGS})

	if(USE_HIP)
		add_library(exatensor STATIC ${EXATENSOR_HIP_SOURCES} $<TARGET_OBJECTS:exatensor_cxx> $<TARGET_OBJECTS:exatensor_fort>)
	else()
		set_source_files_properties(${EXATENSOR_CUDA_SOURCES} PROPERTIES CUDA_SOURCE_PROPERTY_FORMAT OBJ)
		add_library(exatensor STATIC ${EXATENSOR_CUDA_SOURCES} $<TARGET_OBJECTS:exatensor_cxx> $<TARGET_OBJECTS:exatensor_fort>)
		target_compile_options(exatensor PRIVATE ${EXATENSOR_CUDA_FLAGS})
	endif()

	if(USE_HIP)
		set(GPU_BLAS roc::hipblas hip::device)
	else()
		set(GPU_BLAS CUDA::cublas)
	endif()
	if(USE_OPENMP)
		target_link_libraries(exatensor PUBLIC ${GPU_BLAS} OpenMP::OpenMP_C)
	else()
		target_link_libraries(exatensor PUBLIC ${GPU_BLAS})
	endif()
else()
	add_library(exatensor STATIC ${EXATENSOR_FORTRAN_SOURCES} $<TARGET_OBJECTS:exatensor_cxx>)
	target_include_directories(exatensor PUBLIC ${EXATENSOR_INCLUDES})
	target_compile_definitions(exatensor PRIVATE ${EXATENSOR_Fortran_COMPILE_DEFS})
	target_compile_options(exatensor PRIVATE ${EXATENSOR_Fortran_FLAGS})
	if(USE_OPENMP)
		target_link_libraries(exatensor PUBLIC OpenMP::OpenMP_C)
	endif()
endif()

add_library(exatensor::exatensor ALIAS exatensor)

set(EXATENSOR_HEADERS
        DDSS/sys_service.h
	TALSH/timer.h
	TALSH/byte_packet.h
	TALSH/nvtx_profile.h
	TALSH/mem_manager.h
	TALSH/tensor_algebra.h
	TALSH/exatensor.h
	TALSH/tensor_method.hpp
	TALSH/exatensor_task.hpp
	TALSH/exatensorxx.hpp
    )

if(USE_HIP)
	list(APPEND EXATENSOR_HEADERS
		TALSH/device_algebra.hip.h
		TALSH/exatensor_complex.hip.h)
else()
	list(APPEND EXATENSOR_HEADERS
		TALSH/device_algebra.h
		TALSH/exatensor_complex.h)
endif()

if(BUILD_TESTS)
	enable_testing()
	add_executable(exatensor_test main.F90 test.cpp)
	target_link_libraries(exatensor_test exatensor::exatensor)
	target_compile_definitions(exatensor_test PRIVATE ${EXATENSOR_Fortran_COMPILE_DEFS})
	target_compile_options(exatensor_test PRIVATE ${EXATENSOR_Fortran_FLAGS})
	add_test(NAME exatensor_test COMMAND exatensor_test)	
endif()

set_target_properties(exatensor PROPERTIES EXPORT_NAME exatensor)

# Install

include(GNUInstallDirs)
set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/exatensor)

install(TARGETS exatensor
    EXPORT exatensor-targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)


install(FILES ${EXATENSOR_HEADERS} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/exatensor)

#Export the targets to a script
install(EXPORT exatensor-targets
    FILE
        exatensor-targets.cmake
    NAMESPACE
        exatensor::
    DESTINATION
        ${INSTALL_CONFIGDIR}
)

#Create a ConfigVersion.cmake file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/exatensor-config-version.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)

configure_package_config_file(${CMAKE_CURRENT_LIST_DIR}/cmake/exatensor-config.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/exatensor-config.cmake
    INSTALL_DESTINATION ${INSTALL_CONFIGDIR}
    PATH_VARS CMAKE_INSTALL_INCLUDEDIR
)

#Install the config, configversion files
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/exatensor-config.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/exatensor-config-version.cmake
    DESTINATION ${INSTALL_CONFIGDIR}
)


export(EXPORT exatensor-targets
    FILE ${CMAKE_CURRENT_BINARY_DIR}/exatensor-targets.cmake
    NAMESPACE exatensor::)

#Register package in user's package registry
export(PACKAGE exatensor)
