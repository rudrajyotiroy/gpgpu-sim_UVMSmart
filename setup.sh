# see README before running this

ps -p $$ | awk '/bash/ || / sh/ || /zsh/ {exit 1;}' && echo "ERROR ** source setup_environment must be run in a bash, zsh or sh shell; see README" && exit

export CUDA_INSTALL_PATH=/usr/local/cuda-8.0
export PATH=$PATH:$CUDA_INSTALL_PATH/bin
export LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib:$CUDA_INSTALL_PATH/lib64:$CUDA_INSTALL_PATH/lib

export GPGPUSIM_SETUP_ENVIRONMENT_WAS_RUN=
export GPGPUSIM_ROOT="$( cd "$( dirname "$BASH_SOURCE" )" && pwd )"

GPGPUSIM_VERSION_STRING=`cat $GPGPUSIM_ROOT/version | awk '/Version/ {print $8}'`
#Detect Git branch and commit #
GIT_COMMIT=`git log -n 1 | head -1 | sed -re 's/commit (.*)/\1/'`
# GIT_FILES_CHANGED=`git diff --numstat | wc | sed -re 's/^\s+([0-9]+).*/\1./'`
# GIT_FILES_CHANGED+=`git diff --numstat --cached | wc | sed -re 's/^\s+([0-9]+).*/\1/'`
# GPGPUSIM_BUILD_STRING="gpgpu-sim_git-commit-$GIT_COMMIT-modified_$GIT_FILES_CHANGED"

# echo -n "GPGPU-Sim version $GPGPUSIM_VERSION_STRING (build $GPGPUSIM_BUILD_STRING) ";

if [ ! -n "$CUDA_INSTALL_PATH" ]; then
	echo "ERROR ** Install CUDA Toolkit and set CUDA_INSTALL_PATH.";
	return;
fi

if [ ! -d "$CUDA_INSTALL_PATH" ]; then
	echo "ERROR ** CUDA_INSTALL_PATH=$CUDA_INSTALL_PATH invalid (directory does not exist)";
	return;
fi

if [ ! `uname` = "Linux" -a  ! `uname` = "Darwin" ]; then
	echo "ERROR ** Unsupported platform: GPGPU-Sim $GPGPUSIM_VERSION_STRING developed and tested on Linux."
	return;
fi

export PATH=`echo $PATH | sed "s#$GPGPUSIM_ROOT/bin:$CUDA_INSTALL_PATH/bin:##"`
export PATH=$GPGPUSIM_ROOT/bin:$CUDA_INSTALL_PATH/bin:$PATH

# to run the debug build of GPGPU-Sim run:
# source setup_environment debug
NVCC_PATH=`which nvcc`;
if [ $? = 1 ]; then
	echo "";
	echo "ERROR ** nvcc (from CUDA Toolkit) was not found in PATH but required to build GPGPU-Sim.";
	echo "         Try adding $CUDA_INSTALL_PATH/bin/ to your PATH environment variable.";
	echo "         Please also be sure to read the README file if you have not done so.";
	echo "";
	return;
fi

CC_VERSION=`gcc --version | head -1 | awk '{for(i=1;i<=NF;i++){ if(match($i,/^[0-9]\.[0-9]\.[0-9]$/))  {print $i; exit 0}}}'`

CUDA_VERSION_STRING=`$CUDA_INSTALL_PATH/bin/nvcc --version | awk '/release/ {print $5;}' | sed 's/,//'`;
CUDA_VERSION_NUMBER=`echo $CUDA_VERSION_STRING | sed 's/\./ /' | awk '{printf("%02u%02u", 10*int($1), 10*$2);}'`

if [ $CUDA_VERSION_NUMBER -gt 9100 -o $CUDA_VERSION_NUMBER -lt 2030  ]; then
	echo "ERROR ** GPGPU-Sim version $GPGPUSIM_VERSION_STRING not tested with CUDA version $CUDA_VERSION_STRING (please see README)";
	return
fi

if [ $# = '1' ] ;
then
    export GPGPUSIM_CONFIG=gcc-$CC_VERSION/cuda-$CUDA_VERSION_NUMBER/$1
else
    export GPGPUSIM_CONFIG=gcc-$CC_VERSION/cuda-$CUDA_VERSION_NUMBER/release
fi

export QTINC=/usr/include

# change NVOPENCL_LIBDIR to point to your opencl library directory, usually
# /usr/lib or /usr/lib64. Not setting this variable will cause gpgpu-sim to
# build without opencl support.
if [ -f /usr/lib64/libOpenCL.so ]; then
	export NVOPENCL_LIBDIR=/usr/lib64;

	# change NVOPENCL_INCDIR to point to your opencl include directory.
	if [ -f /usr/include/CL/cl.h ]; then
		export NVOPENCL_INCDIR=/usr/include/;
	elif [ -f $CUDA_INSTALL_PATH/include/CL/cl.h ]; then
		export NVOPENCL_INCDIR=$CUDA_INSTALL_PATH/include/;
	fi
fi

# setting LD_LIBRARY_PATH as follows enables GPGPU-Sim to be invoked by 
# native CUDA and OpenCL applications. GPGPU-Sim is dynamically linked
# against instead of the CUDA toolkit.  This replaces this cumbersome
# static link setup in prior GPGPU-Sim releases.
if [ `uname` = "Darwin" ]; then
	export DYLD_LIBRARY_PATH=`echo $DYLD_LIBRARY_PATH | sed -Ee 's#'$GPGPUSIM_ROOT'\/lib\/[0-9]+\/(debug|release):##'`
	export DYLD_LIBRARY_PATH=$GPGPUSIM_ROOT/lib/$GPGPUSIM_CONFIG:$DYLD_LIBRARY_PATH
else
	export LD_LIBRARY_PATH=`echo $LD_LIBRARY_PATH | sed -re 's#'$GPGPUSIM_ROOT'\/lib\/[0-9]+\/(debug|release):##'`
	export LD_LIBRARY_PATH=$GPGPUSIM_ROOT/lib/$GPGPUSIM_CONFIG:$LD_LIBRARY_PATH
fi


# The following sets OPENCL_REMOTE_GPU_HOST which is used by GPGPU-Sim to
# SSH to remote node to generate PTX for OpenCL kernels when running on 
# a node that does not have an NVIDIA driver installed.
# The remote node should have GPGPU-Sim installed at the same path 
if [ `uname` = "Darwin" ]; then
	HOSTNAME_PREFIX=`hostname -s`;
	export HOSTNAME_DOMAIN=`hostname | sed s/$HOSTNAME_PREFIX\.//`;
else
	HOSTNAME_DOMAIN=`hostname -d`
fi
if [ "x$HOSTNAME_DOMAIN" = "xece.ubc.ca" -a "$OPENCL_REMOTE_GPU_HOST" = "" ]; then
	export OPENCL_REMOTE_GPU_HOST=aamodt-pc05.ece.ubc.ca
fi
HOSTNAME_F=`hostname -f`
if [ "x$HOSTNAME_F" = "x$OPENCL_REMOTE_GPU_HOST" ]; then
	unset OPENCL_REMOTE_GPU_HOST
fi

# The following checks to see if the GPGPU-Sim power model is enabled.
# GPGPUSIM_POWER_MODEL points to the directory where gpgpusim_mcpat is located.
# If this is not set, it checks the default directory "$GPGPUSIM_ROOT/src/gpuwattch/".
if [ -d $GPGPUSIM_ROOT/src/gpuwattch/ ]; then
	if [ ! -f $GPGPUSIM_ROOT/src/gpuwattch/gpgpu_sim.verify ]; then
		echo "ERROR ** gpgpu_sim.verify not found in $GPGPUSIM_ROOT/src/gpuwattch";
		return;
	fi
	export GPGPUSIM_POWER_MODEL=$GPGPUSIM_ROOT/src/gpuwattch/;
	echo "configured with GPUWattch.";
elif [ -n "$GPGPUSIM_POWER_MODEL" ]; then
	if [ ! -f $GPGPUSIM_POWER_MODEL/gpgpu_sim.verify ]; then
		echo "";
		echo "ERROR ** gpgpu_sim.verify not found in $GPGPUSIM_ROOT/src/gpuwattch/ - Either incorrect directory or incorrect McPAT version";
		return;
	fi
	echo "configure with power model in $GPGPUSIM_POWER_MODEL.";
elif [ ! -d $GPGPUSIM_POWER_MODEL ]; then
		echo "";
		echo "ERROR ** GPGPUSIM_POWER_MODEL ($GPGPUSIM_POWER_MODEL) does not exist... Please set this to the gpgpusim_mcpat directory or unset this environment variable.";
		return;
else
	echo "configured without a power model.";
fi

echo "setup_environment succeeded";

export GPGPUSIM_SETUP_ENVIRONMENT_WAS_RUN=1
cd /root/uvmsmart/benchmarks/Managed/2DCONV/
echo "Entrypoint ended";

/bin/bash "$@"