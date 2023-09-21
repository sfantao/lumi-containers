#FROM registry.suse.com/bci/bci-base:15.3.17.20.5
#FROM registry.suse.com/bci/bci-base:15.3.17.20.101
FROM registry.suse.com/bci/bci-base:15.3.17.20.145

ARG SERVER_PORT

#
# Disable BCI repros
#

RUN set -eux ; \
  sed -i 's#enabled=1#enabled=0#g' /etc/zypp/repos.d/SLE_BCI.repo 

RUN set -eux ; \
  zypper -n addrepo http://download.opensuse.org/distribution/leap/15.3/repo/oss/ myrepo1 ; \
  echo 'gpgcheck=0' >> /etc/zypp/repos.d/myrepo1.repo ; \
  zypper -n addrepo https://download.opensuse.org/repositories/devel:/languages:/perl/SLE_15_SP3 myrepo2 ; \
  echo 'gpgcheck=0' >> /etc/zypp/repos.d/myrepo2.repo
  
RUN set -eux ; \
  sed -i 's#gpgcheck=1#gpgcheck=0#g' /etc/zypp/repos.d/*.repo

#
# Install build dependencies
#
RUN set -eux; \
  zypper -n refresh ; \
  zypper --no-gpg-checks -n install -y --force-resolution \
    git cmake gcc10 gcc10-c++ gcc10-fortran zlib-devel numactl awk patch tar autoconf automake libtool libjson-c-devel graphviz ncurses-devel nano which ; \
  zypper clean

#
# Cray info
#
ENV CPE_VERSION "23.03"
ENV CPE_URL="http://localhost:$SERVER_PORT/cpe-$CPE_VERSION.tar"
ENV LIBFABRIC_VERSION "1.15.2.0" 
ENV LIBFABRIC_PATH /opt/cray/libfabric/$LIBFABRIC_VERSION
ENV MPICH_PATH "/opt/cray/pe/mpich/8.1.25/ofi/crayclang/10.0"
ENV LD_LIBRARY_PATH /opt/cray-deps:$LIBFABRIC_PATH/lib64:$MPICH_PATH/lib:/opt/cray/pe/lib64:/opt/cray/pe/lib64/cce

ENV REMOVE_CRAY_DEPS 'rm -rf /opt/cray /opt/cray-deps /usr/lib64/libcxi.so*'

ENV ROCM_RPM https://repo.radeon.com/amdgpu-install/5.5.1/sle/15.3/amdgpu-install-5.5.50501-1.noarch.rpm 
ENV ROCM_RELEASE 5.5.1

RUN set -eux ; \
  zypper --no-gpg-checks -n install $ROCM_RPM

RUN set -eux ; \
  sed -i 's#gpgcheck=1#gpgcheck=0#g' /etc/zypp/repos.d/*.repo

RUN set -eux ; \
 amdgpu-install -y --no-dkms --usecase=rocm --rocmrelease=$ROCM_RELEASE

#
# ROCm environment
#
ENV ROCM_PATH /opt/rocm-$ROCM_RELEASE
ENV PATH $ROCM_PATH/bin:$ROCM_PATH/llvm/bin:$PATH
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$ROCM_PATH/lib

#
# Mark RCCL as non-debug - this can me overriden by RCCL debug build. 
#
ENV RCCL_DEBUG 0

#
# Fix rocm-smi lib
#
RUN set -eux ; \
  cd /opt ; \
  curl -LO http://localhost:$SERVER_PORT/rocm-5.5.1-rocm-smi-lib.patch ; \
  git clone -b rocm-$ROCM_RELEASE https://github.com/RadeonOpenCompute/rocm_smi_lib /opt/mybuild ; \
  mkdir -p /opt/mybuild/build ; \
  \
  cd /opt/mybuild ; \
  git apply < /opt/rocm-5.5.1-rocm-smi-lib.patch ; \
  rm -rf /opt/rocm-5.5.1-rocm-smi-lib.patch ; \
  \  
  cd /opt/mybuild/build ; \
  cmake -DCMAKE_INSTALL_PREFIX=/opt/rocm-patched .. ; \
  make -j32 ; \
  make -j32 install ; \
  cd / ; rm -rf /opt/mybuild

RUN set -eux ; \
  for i in liboam librocm_smi64 ; do \
    src=$(find /opt/rocm-$ROCM_RELEASE -type f -iname $i.so*) ; \
    dst=$(find /opt/rocm-patched -type f -iname $i.so*) ; \
    rm -rf $src ; \
    ln -s $dst $src ; \
  done

RUN set -eux ; \
  cd $ROCM_PATH/bin ; \
  for i in rocm_agent_enumerator rocminfo ; do \
    rm -rf $i ; \
    curl -LO http://localhost:$SERVER_PORT/$i ; \
    chmod +x $i ; \
  done
#
# Install miniconda
#
RUN set -eux ; \
  curl -LO https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh ; \
  bash ./Miniconda3-* -b -p /opt/miniconda3 -s ; \
  rm -rf ./Miniconda3-*

ENV WITH_CONDA "source /opt/miniconda3/bin/activate base"
RUN set -eux ; \
  cd / ; \
  curl -LO $CPE_URL ; \
  tar -xf *.tar ; rm -rf *.tar ; \
  \
  git clone -b cxi https://github.com/ROCmSoftwarePlatform/aws-ofi-rccl /opt/mybuild ; \
  cd /opt/mybuild ; \
  ./autogen.sh ; \
  \
  cd /opt/mybuild ; \
  export CPATH=$LIBFABRIC_PATH/include ; \
  export LIBRARY_PATH=$LD_LIBRARY_PATH ; \
  LDFLAGS='-lcxi' CC=gcc-10 ./configure --with-libfabric=$LIBFABRIC_PATH --enable-trace --with-hip=$ROCM_PATH --with-rccl=$ROCM_PATH/rccl --disable-tests ; \
  LDFLAGS='-lcxi' CC=gcc-10 nice make -j ; \
  \
  mkdir /opt/aws-ofi-rccl ; \
  mv src/.libs/librccl-net.so* /opt/aws-ofi-rccl ; \
  rm -rf /opt/mybuild ; \
  $REMOVE_CRAY_DEPS
  
#
# Add relevant libs to execution environment
#
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/opt/aws-ofi-rccl
ENV CXI_FORK_SAFE=1
ENV CXI_FORK_SAFE_HP=1
ENV FI_CXI_DISABLE_CQ_HUGETLB=1
RUN set -eux ; \
  cd / ; \
  curl -LO $CPE_URL ; \
  tar -xf *.tar ; rm -rf *.tar ; \
  \
  git clone https://github.com/ROCmSoftwarePlatform/rccl-tests /opt/mybuild ; \
  #git clone -b remove-stream-queries https://github.com/sfantao/rccl-tests /opt/mybuild ; \
  sed -i 's/-std=c++14/-std=c++14 --amdgpu-target=gfx90a:xnack- --amdgpu-target=gfx90a:xnack+/g' /opt/mybuild/src/Makefile ; \
  \
  cd /opt/mybuild ; \
  CC=gcc=10 \
    DEBUG=$RCCL_DEBUG \
    CXX=g++-10 \
    MPI_HOME=$MPICH_PATH \
    ROCM_PATH=$ROCM_PATH \
    MPI=1 \
    NCCL_HOME=$ROCM_PATH/rccl \
    nice make -j ; \
  mkdir /opt/rccltests ; \
  mv /opt/mybuild/build/* /opt/rccltests ; \
  rm -rf /opt/mybuild ; \
  $REMOVE_CRAY_DEPS
  
#
# Install conda environment
# 
ARG PYTHON_VERSION
RUN $WITH_CONDA; set -eux ; \
  conda create -n tensorflow python=$PYTHON_VERSION
  
ENV WITH_CONDA "source /opt/miniconda3/bin/activate tensorflow"

ARG TENSORFLOW_VERSION
RUN $WITH_CONDA; set -eux ; \
  pip install tensorflow-rocm==$TENSORFLOW_VERSION

#
# Install horovod
#
ARG HOROVOD_VERSION
RUN $WITH_CONDA ; set -eux ; \
  cd / ; \
  curl -LO $CPE_URL ; \
  tar -xf *.tar ; rm -rf *.tar ; \
  cd $MPICH_PATH/../.. ; \
  ln -s crayclang cray ; \
  \
  HOROVOD_WITHOUT_MXNET=1 \
    HOROVOD_WITHOUT_PYTORCH=1 \
    HOROVOD_GPU=ROCM \
    HOROVOD_GPU_OPERATIONS=NCCL \
    HOROVOD_WITHOUT_GLOO=1 \
    HOROVOD_WITH_MPI=1 \
    HOROVOD_WITH_TENSORFLOW=1 \
    HOROVOD_ROCM_PATH=$ROCM_PATH \
    HOROVOD_RCCL_HOME=$ROCM_PATH/rccl \
    RCCL_INCLUDE_DIRS=$ROCM_PATH/rccl/include \
    HOROVOD_RCCL_LIB=$ROCM_PATH/rccl/lib \
    HCC_AMDGPU_TARGET=gfx90a \
    CMAKE_PREFIX_PATH=$MPICH_PATH \
    pip install --no-cache-dir --force-reinstall --verbose horovod==$HOROVOD_VERSION ; \
    rm -rf /opt/mybuild; \
    $REMOVE_CRAY_DEPS

#
# Install OpenNMT if requested
#
ARG OPENNMT_VERSION
RUN $WITH_CONDA ; set -eux ; \
  if [ -z "$OPENNMT_VERSION" ] ; then exit 0; fi ; \
  pip install opennmt-tf==$OPENNMT_VERSION
    