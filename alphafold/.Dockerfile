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

ENV ROCM_RPM https://repo.radeon.com/amdgpu-install/5.5.3/sle/15.3/amdgpu-install-5.5.50503-1.noarch.rpm 
ENV ROCM_RELEASE 5.5.3

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
#
# Set the compiler for the builds to be GCC 10.
#
RUN set -eux ; \ 
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 50  ; \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 50  ; \
  true

ENV CC gcc
ENV CXX g++

#
# Install build dependencies
#
RUN set -eux; \
  zypper -n refresh ; \
  zypper --no-gpg-checks -n install -y --force-resolution \
    xz binutils-gold bazel ; \
  zypper clean

#
# Install aria2c to assist downloading datasets
#
ARG ARIA2_VERSION
RUN set -eux ; \
  mkdir -p /opt/builds/aria2 ; \
  cd /opt/builds/aria2 ; \
  curl -LO https://github.com/aria2/aria2/releases/download/release-$ARIA2_VERSION/aria2-$ARIA2_VERSION.tar.xz ; \
  tar -xf aria2-$ARIA2_VERSION.tar.xz ; \
  mkdir aria2-$ARIA2_VERSION/build ; \
  cd aria2-$ARIA2_VERSION/build ; \
  ../configure --prefix=/opt/aria2 ; \
  make -j ; \
  make -j install ; \
  rm -rf /opt/builds
  
ENV PATH /opt/aria2/bin:$PATH

#
# Install hh-suite.
#
ARG HHSUITE_VERSION
ENV HHSUITE_PATH /opt/hh-suite
RUN set -eux ; \
  mkdir -p /opt/builds ; \
  git clone --branch v$HHSUITE_VERSION https://github.com/soedinglab/hh-suite.git /opt/builds/hh-suite ; \
  mkdir /opt/builds/hh-suite/build ; \
  cd /opt/builds/hh-suite/build ; \
  cmake -DCMAKE_INSTALL_PREFIX=$HHSUITE_PATH .. ; \
  make -j   ; \
  make -j install  ; \
  rm -rf /opt/builds

#
# Install conda environment
# 
ARG PYTHON_VERSION
RUN $WITH_CONDA; set -eux ; \
  conda create -n alphafold python=$PYTHON_VERSION ; \
  conda activate alphafold ; \
  conda install -y \
    swig \
    numpy \
    Cython \
    dm-tree \
    biopython \
    pandas ; \
  conda install -y -c conda-forge \
    pdbfixer==1.9 ; \
  conda install -y -c bioconda \
    kalign2 ; \
  pip install \
    tensorflow-rocm==2.11.1.550 \
    ml-collections \
    dm-haiku \
    hmmer

ENV WITH_CONDA "source /opt/miniconda3/bin/activate alphafold"

#
# Install JAX
#
ARG JAX_VERSION=0.4.13
RUN $WITH_CONDA; set -eux ; \
  git clone -b rocm-jaxlib-v$JAX_VERSION https://github.com/ROCmSoftwarePlatform/xla /opt/xla ; \
  git clone -b rocm-jaxlib-v$JAX_VERSION https://github.com/ROCmSoftwarePlatform/jax /opt/jax ; \
  \
  cd /opt/jax ; \
  export TEST_TMPDIR=/opt/.bazel ; \
  python build/build.py --enable_rocm --rocm_path=$ROCM_PATH \
    --rocm_amdgpu_targets=gfx908,gfx90a \
    --bazel_options=--override_repository=xla=/opt/xla \
    --bazel_options=--jobs=32 \
    --bazel_startup_options=--host_jvm_args=-Xmx512m \
    --bazel_startup_options=--host_jvm_args=-Xms256m ; \
  mkdir -p /opt/wheels ; \
  cp /opt/jax/dist/jaxlib-*.whl /opt/wheels ; \
  rm -rf /opt/jax /opt/xla /opt/.bazel

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/jaxlib-*.whl; \
  pip install jax==$JAX_VERSION
  
ENV JAX_PLATFORMS "rocm,cpu"

#
# Install OpenMM
#

RUN set -eux; \
  zypper -n refresh ; \
  zypper --no-gpg-checks -n install -y --force-resolution \
    doxygen ; \
  zypper clean
  
ARG OPENMM_VERSION
ARG OPENMM_HIP_VERSION
ENV OPENMM_PATH /opt/openmm
RUN $WITH_CONDA; set -eux ; \
  mkdir -p /opt/builds/build /opt/builds/build-hip; \
  cd /opt/builds ; \
  \
  git clone https://github.com/openmm/openmm.git -b $OPENMM_VERSION /opt/builds/openmm ; \
  cd /opt/builds/build ; \
  cmake /opt/builds/openmm -DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang \
                           -DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++ \
                           -DCMAKE_INSTALL_PREFIX=$OPENMM_PATH \
                           -DOPENMM_BUILD_COMMON=ON \
                           -DOPENMM_PYTHON_USER_INSTALL=OFF \
                           -DPYTHON_EXECUTABLE=$(which python) \
                           -DCMAKE_BUILD_TYPE=Release ; \
  make -j ; \
  make -j install ; \
  make -j PythonInstall ; \
  \ 
  git clone https://github.com/amd/openmm-hip.git /opt/builds/openmm-hip ; \
  cd /opt/builds/openmm-hip ; \
  git checkout -b mydev $OPENMM_HIP_VERSION ; \
  cd /opt/builds/build-hip ; \
  cmake /opt/builds/openmm-hip -DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang \
                                      -DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++ \
                                      -DOPENMM_DIR=$OPENMM_PATH \
                                      -DOPENMM_SOURCE_DIR=/opt/builds/openmm \
                                      -DCMAKE_INSTALL_PREFIX=$OPENMM_PATH \
                                      -DCMAKE_BUILD_TYPE=Release ; \
  make -j ; \
  make -j install ; \
  rm -rf /opt/builds ; \
  true
  
#
# Clone alphafold 
#
ARG ALPHAFOLD_VERSION
ENV ALPHAFOLD_PATH /opt/alphafold
RUN set -eux ; \
  git clone https://github.com/deepmind/alphafold $ALPHAFOLD_PATH ; \
  \
  cd $ALPHAFOLD_PATH ; \
  git checkout -b mydev $ALPHAFOLD_VERSION ; \
  sed -i 's#CUDA#HIP#g' alphafold/relax/amber_minimize.py ; \
  \
  cd $ALPHAFOLD_PATH/alphafold/common ; \
  curl -LO https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

RUN $WITH_CONDA ; set -eux ; \
  rm $CONDA_PREFIX/lib/libstdc++.so* ; \
  ln -s /usr/lib64/libstdc++.so* $CONDA_PREFIX/lib
