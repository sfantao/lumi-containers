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

ENV ROCM_RPM https://repo.radeon.com/amdgpu-install/5.4.5/sle/15.3/amdgpu-install-5.4.50405-1.noarch.rpm
ENV ROCM_RELEASE 5.4.5

RUN set -eux ; \
  zypper --no-gpg-checks -n install $ROCM_RPM

RUN set -eux ; \
  sed -i 's#gpgcheck=1#gpgcheck=0#g' /etc/zypp/repos.d/*.repo

RUN set -eux ; \
 amdgpu-install -y --no-dkms --usecase=hiplibsdk,rocm --rocmrelease=$ROCM_RELEASE

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
# Put libstdc++ in front of the LD_LIBRARY_PATH
#
RUN set -eux ; \
  cd $ROCM_PATH/lib ; \
  ln -s /usr/lib64/libstdc++.so* .
#
# Install miniconda
#
RUN set -eux ; \
  curl -LO https://repo.anaconda.com/miniconda/Miniconda3-py310_23.3.1-0-Linux-x86_64.sh ; \
  bash ./Miniconda3-* -b -p /opt/miniconda3 -s ; \
  rm -rf ./Miniconda3-*

ENV WITH_CONDA "source /opt/miniconda3/bin/activate base"
#
# Install conda environment
# 
ARG PYTHON_VERSION
RUN $WITH_CONDA; set -eux ; \
  conda create -n mpi4py python=$PYTHON_VERSION

ENV WITH_CONDA "source /opt/miniconda3/bin/activate mpi4py"
ENV CUPY_VERSION 12.2.0
RUN $WITH_CONDA ; set -eux ; \
  export HCC_AMDGPU_TARGET=gfx90a ; \
  export CUPY_INSTALL_USE_HIP=1 ; \
  export ROCM_HOME=$ROCM_PATH ; \
  export CC=$ROCM_PATH/llvm/bin/clang ; \
  export CXX=$ROCM_PATH/llvm/bin/clang++ ; \
  pip install cupy==$CUPY_VERSION
#
# Install MPI4PY - we use clang to build has the default linker allow undefined symbols 
# in all dependency libs - '-Wl,--allow-shlib-undefined' with gcc/GNU linker should
# be equivalent.   
#
ENV MPI4PY_VERSION 3.1.4
RUN $WITH_CONDA ; set -eux ; \
  cd / ; \
  curl -LO $CPE_URL ; \
  tar -xf *.tar ; rm -rf *.tar ; \
  \
  mkdir /opt/builds ; \
  cd /opt/builds ; \
  curl -LO https://github.com/mpi4py/mpi4py/releases/download/$MPI4PY_VERSION/mpi4py-$MPI4PY_VERSION.tar.gz ; \
  tar -xf mpi4py-$MPI4PY_VERSION.tar.gz ; \
  rm -rf mpi4py-$MPI4PY_VERSION.tar.gz ; \
  \
  cd /opt/builds/mpi4py-* ; \
  \
  echo "[lumi]" >> mpi.cfg ; \
  echo "mpi_dir              = $MPICH_PATH" >> mpi.cfg ; \
  echo "mpicc                = $ROCM_PATH/llvm/bin/clang" >> mpi.cfg ; \
  echo "mpicxx               = $ROCM_PATH/llvm/bin/clang++" >> mpi.cfg ; \
  echo "libraries            = mpi_cray  mpi_gtl_hsa" >> mpi.cfg ; \
  echo "library_dirs         = %(mpi_dir)s/lib:%(mpi_dir)s/../../../gtl/lib:$LIBFABRIC_PATH/lib64:/opt/cray/pe/lib64:/opt/cray/pe/lib64/cce/:/opt/cray-deps" >> mpi.cfg ; \
  echo "include_dirs         = %(mpi_dir)s/include" >> mpi.cfg ; \
  \
  python setup.py build --mpi=lumi ; \
  python setup.py install ; \
  cd / ; rm -rf /opt/builds ; \
  $REMOVE_CRAY_DEPS
ENV OSU_VERSION 7.2
ENV OSU_PATH /opt/osu

#
# We can't run MPI during configure phase as we don't really have MPI available at build time.
# Therefore we trick configure to believe MPI exists and we just link during the build phase.
#
RUN set -eux ; \
  cd / ; \
  curl -LO $CPE_URL ; \
  tar -xf *.tar ; rm -rf *.tar ; \
  \
  mkdir /opt/builds ; \
  cd /opt/builds ; \
  curl -LO  https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-$OSU_VERSION.tar.gz ; \
  tar -xf osu-*.tar.gz ; \
  rm -rf osu-*.tar.gz ; \
  \
  cd /opt/builds/osu-*/ ; \
  \
  sed -i 's/$ac_cv_func_MPI_Init/yes/g' configure ; \
  sed -i 's/$ac_cv_func_MPI_Accumulate/yes/g' configure ; \
  sed -i 's/$ac_cv_func_MPI_Get_accumulate/yes/g' configure ; \
  \
  CC=$ROCM_PATH/llvm/bin/clang CXX=$ROCM_PATH/llvm/bin/clang++ \
    CFLAGS="-I$MPICH_PATH/include" \
    ./configure --enable-rocm --with-rocm=$ROCM_PATH --prefix=$OSU_PATH ; \
  make LDFLAGS="-L$MPICH_PATH/../../../gtl/lib -Wl,-rpath=$MPICH_PATH/../../../gtl/lib -L$MPICH_PATH/lib -lmpi_cray -lmpi_gtl_hsa -L$ROCM_PATH/lib  -lamdhip64" -j install ; \
  \
  cd / ; rm -rf /opt/builds ; \
  $REMOVE_CRAY_DEPS
