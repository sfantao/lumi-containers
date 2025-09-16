#
# Install conda environment
# 
ARG PYTHON_VERSION
RUN $WITH_CONDA; set -eux ; \
  conda create -n pytorch python=$PYTHON_VERSION ; \
  conda activate pytorch ; \
  conda install -y ninja pillow cmake pyyaml
ENV WITH_CONDA "source /opt/miniconda3/bin/activate pytorch"

# Repository for the wheel files
RUN set -eux ; \
  mkdir /opt/wheels
  
#
# Install pytorch
# 

# PyTorch comes with RCCL from ROCm 6.0.0 which cause a segmentation fault 
# in the tests. It's supspected it's related to https://github.com/ROCm/rccl/pull/1153
# Copying the RCCL library from /opt/rocm, solve the issue.

ENV PYTORCH_ROCM_ARCH gfx90a 
ARG PYTORCH_VERSION
ARG PYTORCH_DEBUG
ARG PYTORCH_RELWITHDEBINFO

RUN $WITH_CONDA; set -eux ; \
  pip3 install --pre torch==${PYTORCH_VERSION} --index-url https://download.pytorch.org/whl/ ; \
  cp /opt/rocm/lib/librccl.so $(dirname $(python -c 'import torch; print(torch.__file__)'))/lib

# Problematic for RCCL to use conda libstdc++.so from conda.
RUN $WITH_CONDA; set -eux ; \
  rm $CONDA_PREFIX/lib/libstdc++.*

#
# Pytorch dependencies
#
RUN $WITH_CONDA; set -eux ; \
  pip install packaging

ARG APEX_VERSION
RUN $WITH_CONDA; set -eux ; \
  cd / ; \
  rm -rf /opt/mybuild ; \
  git clone --recursive https://github.com/rocm/apex /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev $APEX_VERSION ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
  \
  # cp /opt/miniconda3/envs/pytorch/lib/python3.12/site-packages/torch/include/torch/csrc/cuda/CUDAPluggableAllocator.h \
  #    /opt/miniconda3/envs/pytorch/lib/python3.12/site-packages/torch/include/torch/csrc/cuda/CUDAPluggableAllocator.h.orig ; \
  # sed -i 's#defined(TORCH_HIP_VERSION)#defined(USE_ROCM)#g' \
  #   /opt/miniconda3/envs/pytorch/lib/python3.12/site-packages/torch/include/torch/csrc/cuda/CUDAPluggableAllocator.h ; \
  # \
  TORCH_DONT_CHECK_COMPILER_ABI=1 \
    CC=clang \
    CXX=clang++ \
    nice python setup.py bdist_wheel --cpp_ext --cuda_ext ; \
  \
  # cp /opt/miniconda3/envs/pytorch/lib/python3.12/site-packages/torch/include/torch/csrc/cuda/CUDAPluggableAllocator.h.orig \
  #    /opt/miniconda3/envs/pytorch/lib/python3.12/site-packages/torch/include/torch/csrc/cuda/CUDAPluggableAllocator.h ; \
  # \
  cp -rf dist/* /opt/wheels ; \
  rm -rf /opt/mybuild
  
RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/apex-*.whl

ARG TORCHVISION_VERSION
RUN $WITH_CONDA; set -eux ; \
  pip3 install --pre torchvision==$TORCHVISION_VERSION --index-url https://download.pytorch.org/whl/

#
# AMD-SMI
#
RUN $WITH_CONDA; set -eux ; \
  cd $ROCM_PATH/share/amd_smi ; \
  python3 -m pip wheel . --wheel-dir=/opt/wheels ; \
  pip install /opt/wheels/amdsmi-*.whl

ARG TORCHDATA_VERSION
RUN $WITH_CONDA; set -eux ; \
  pip3 install --pre torchdata==$TORCHDATA_VERSION --index-url https://download.pytorch.org/whl/
   
ARG TORCHTEXT_VERSION
RUN $WITH_CONDA; set -eux ; \
  pip3 install --pre torchtext==$TORCHTEXT_VERSION --index-url https://download.pytorch.org/whl/

ARG TORCHAUDIO_VERSION
RUN $WITH_CONDA; set -eux ; \
  pip3 install --pre torchaudio==${TORCHAUDIO_VERSION} --index-url https://download.pytorch.org/whl/

#
# Deepspeed
#
ENV RUSTUP_HOME /opt/rust
ENV CARGO_HOME /opt/rust
RUN set -eux ; \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /opt/rust.sh ; \
  sh /opt/rust.sh -y --no-modify-path ; \
  rm -rf /opt/rust.sh

ENV PATH $PATH:/opt/rust/bin

RUN $WITH_CONDA; set -eux ; \
  conda install -y  -c conda-forge oneccl-devel

ARG DEEPSPEED_VERSION
RUN $WITH_CONDA; set -eux ; \
  ln -s $(which gcc-12) /opt/rust/bin/cc ; \
  CC=gcc-12 CXX=g++-12 \
  DS_BUILD_AIO=0 \
  DS_BUILD_CCL_COMM=1 \
  DS_BUILD_CPU_ADAM=1 \
  DS_BUILD_CPU_LION=1 \
  DS_BUILD_EVOFORMER_ATTN=0 \
  DS_BUILD_FUSED_ADAM=1 \
  DS_BUILD_FUSED_LION=1 \
  DS_BUILD_CPU_ADAGRAD=0 \
  DS_BUILD_FUSED_LAMB=1 \
  DS_BUILD_QUANTIZER=0 \
  DS_BUILD_RANDOM_LTD=0 \
  DS_BUILD_SPARSE_ATTN=0 \
  DS_BUILD_TRANSFORMER=0 \
  DS_BUILD_TRANSFORMER_INFERENCE=0 \
  DS_BUILD_STOCHASTIC_TRANSFORMER=1 \
  DS_ACCELERATOR=cuda \
  pip install deepspeed==$DEEPSPEED_VERSION --global-option="build_ext" --global-option="-j32" ; \
#  ds_report ; \
  true

#
# flash-attention
#
ARG FLASH_ATTENTION_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone -b v2.7.3 --recursive https://github.com/Dao-AILab/flash-attention /opt/mybuild ; \
  cd /opt/mybuild ; \
  cp -rf benchmarks /opt/wheels/flash_attn-benchmarks ; \
  \
  rm -rf build ; \
  MAX_JOBS=32 \
  CC=gcc-12 \
  CXX=g++-12 \
  GPU_ARCHS="gfx90a" \
    python setup.py bdist_wheel ; \
  cp -rf dist/* /opt/wheels ; \
  \
  rm -rf /opt/mybuild 

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/flash_attn-*.whl

#
# xformers - tested with 06b548c
#
RUN $WITH_CONDA; set -eux ; \
  git clone --recursive -b develop https://github.com/ROCm/xformers /opt/mybuild ; \
  cd /opt/mybuild ; \
  \
  rm -rf build ; \
  CC=gcc-12 \
  CXX=g++-12 \
  HIP_ARCHITECTURES="gfx90a" \
  PYTORCH_ROCM_ARCH="gfx90a" \
  python setup.py bdist_wheel ; \
  cp -rf dist/* /opt/wheels ; \
  \
  rm -rf /opt/mybuild 

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/xformers-*.whl

RUN $WITH_CONDA; set -eux ; \
  pip install \
    scipy==1.12.0 \
    matplotlib==3.8.2 \
    pandas==2.2.0 \
    seaborn==0.13.2

# 
# Bits and bytes - tested with 35266ea (was e4fe8b5)
#
RUN $WITH_CONDA; set -eux ; \ 
  git clone https://github.com/ROCm/bitsandbytes /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev 35266ea ; \
  pip install -r requirements-dev.txt ; \
  cmake -DCOMPUTE_BACKEND=hip -DBNB_ROCM_ARCH="gfx90a" -S . ; \
  nice make -j ; \
  python setup.py bdist_wheel ; \
  cp dist/bitsandbytes-*.whl /opt/wheels ; \
  \
  cd / ; \
  rm -rf /opt/mybuild ; \
  true

RUN $WITH_CONDA; set -eux ; \ 
  pip install /opt/wheels/bitsandbytes-*.whl

#
# Some other packages we may need
#
RUN $WITH_CONDA; set -eux ; \ 
  pip install \
    'numpy<2' \
    transformers==4.46.3 \
    sentencepiece==0.2.0 \
    protobuf==5.27.1 \
    accelerate==0.34.2 \
    tensorboard==2.18.0 \
    openpyxl==3.1.5

#
# VLLM
#
RUN $WITH_CONDA; set -eux ; \ 
  pip install \
    setuptools_scm ; \
  pip install --upgrade \ 
    setuptools>=77.0.3

ARG VLLM_VERSION
RUN $WITH_CONDA ; set -eux ; \
  git clone --recursive -b $VLLM_VERSION https://github.com/vllm-project/vllm /opt/mybuild ; \
  \
  cd /opt/mybuild ; \
  CC=gcc-12 \
    CXX=g++-12 \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  \
  rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  pip install \
    /opt/wheels/vllm-*.whl

RUN set -eux; \
  zypper -n refresh ; \
  zypper --no-gpg-checks -n install -y --force-resolution \
    libzstd-devel ; \
  zypper clean

#
# LLVM triton uses - otherwise it will download binaries with glibc compatibility issues
# maybe need zstd: make CC=gcc-12 CXX=g++-12 PREFIX=/aotriton/zstd -j install
ARG TRITON_LLVM_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone https://github.com/llvm/llvm-project /opt/llvm-project ; \
  cd /opt/llvm-project ; \
  git checkout -b mydev $TRITON_LLVM_VERSION ; \
  \
  mkdir /opt/llvm-project/build ; \
  cd /opt/llvm-project/build ; \
  \
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_PROJECTS="mlir;llvm;lld" \
    -DLLVM_TARGETS_TO_BUILD="host;NVPTX;AMDGPU" \
    -DCMAKE_CXX_COMPILER=g++-12 \
    -DCMAKE_C_COMPILER=gcc-12 \
    ../llvm ; \
  ninja ; \
  \
  # for i in /opt/llvm-project/* ; do \
  #   if [ $i = "/opt/llvm-project/build" ] ; then continue ; else rm -rf $i ; fi ; \
  # done ; \
  true

ARG TRITON_FINAL_LLVM_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone https://github.com/llvm/llvm-project /opt/llvm-project-final ; \
  cd /opt/llvm-project-final ; \
  git checkout -b mydev $TRITON_FINAL_LLVM_VERSION ; \
  \
  mkdir /opt/llvm-project-final/build ; \
  cd /opt/llvm-project-final/build ; \
  \
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_ENABLE_PROJECTS="mlir;llvm;lld" \
    -DLLVM_TARGETS_TO_BUILD="host;NVPTX;AMDGPU" \
    -DCMAKE_CXX_COMPILER=g++-12 \
    -DCMAKE_C_COMPILER=gcc-12 \
    ../llvm ; \
  ninja ; \
  \
  # for i in /opt/llvm-project-final/* ; do \
  #   if [ $i = "/opt/llvm-project-final/build" ] ; then continue ; else rm -rf $i ; fi ; \
  # done ; \
  true

#
# Triton that AOTRITON uses is built by it, so we used the final one
# Note that there is already triton that came with Pytorch.
#
# Use this LLVM so that aotriton works.
ENV LLVM_BUILD_DIR=/opt/llvm-project/build
ENV LLVM_INCLUDE_DIRS=$LLVM_BUILD_DIR/include
ENV LLVM_LIBRARY_DIR=$LLVM_BUILD_DIR/lib
ENV LLVM_SYSPATH=$LLVM_BUILD_DIR

ARG TRITON_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone -b $TRITON_VERSION --recursive https://github.com/rocm/triton /opt/mybuild ; \
  cd /opt/mybuild ; \
  CC=gcc-12 \
    CXX=g++-12 \
    pip wheel --no-deps -e . -w /opt/wheels ; \
    cd / ; rm -rf /opt/mybuild

# RUN $WITH_CONDA; set -eux ; \
#     pip install /opt/wheels/triton-*.whl ; \
#     true

# Use this LLVM so that aotriton works.
ENV LLVM_BUILD_DIR=/opt/llvm-project-final/build
ENV LLVM_INCLUDE_DIRS=$LLVM_BUILD_DIR/include
ENV LLVM_LIBRARY_DIR=$LLVM_BUILD_DIR/lib
ENV LLVM_SYSPATH=$LLVM_BUILD_DIR

ARG TRITON_FINAL_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone --recursive https://github.com/triton-lang/triton /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev $TRITON_FINAL_VERSION ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
  cd /opt/mybuild ; \
  CC=gcc-12 \
    CXX=g++-12 \
    pip wheel --no-deps -e python -w /opt/wheels ; \
    cd / ; rm -rf /opt/mybuild

# Install after aotriton is built so it does not conflict.
# RUN $WITH_CONDA; set -eux ; \
#     pip install /opt/wheels/triton-*.whl ; \
#     true

#
# AOTRITON for TE
# 
ENV LLVM_BUILD_DIR=/opt/llvm-project/build
ENV LLVM_INCLUDE_DIRS=$LLVM_BUILD_DIR/include
ENV LLVM_LIBRARY_DIR=$LLVM_BUILD_DIR/lib
ENV LLVM_SYSPATH=$LLVM_BUILD_DIR

ARG AOTRITON_VERSION
RUN $WITH_CONDA; set -eux ; \
  git clone --recursive -b $AOTRITON_VERSION https://github.com/ROCm/aotriton /opt/mybuild; \
  mkdir /opt/mybuild/build ; \
  cd /opt/mybuild/build ; \
  \
  echo '#!/bin/bash -eux' > clang++ ; \
  echo 'exec $ROCM_PATH/llvm/bin/clang++ -Wno-deprecated-declarations $@' >> clang++ ; \
  chmod +x clang++ ; \
  export PATH=$(pwd):$PATH ; \
  \
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=/opt/aotriton \
    -DCMAKE_BUILD_TYPE=Release \
    -DAOTRITON_GPU_BUILD_TIMEOUT=0 \
    -DAOTRITON_TARGET_ARCH=gfx90a \
    -DAMDGPU_TARGETS=gfx90a \
    -G Ninja \
    -DCMAKE_CXX_COMPILER=g++-12 \
    -DCMAKE_C_COMPILER=gcc-12 ; \
  \
  ninja install ; \
  \
  cd / ; rm -rf /opt/mybuild

ENV LD_LIBRARY_PATH /opt/aotriton/lib:$LD_LIBRARY_PATH

#
# Add aiter for vLLM
#
ARG AITER_VERSION
RUN $WITH_CONDA; set -eux ; \
  rm -rf /opt/mybuild ;\
  git clone https://github.com/ROCm/aiter /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev $AITER_VERSION ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
#  sed -i 's#{__package__}.{md_name}#private_{__package__}.{md_name}#g' aiter/jit/core.py ; \
  CC=clang \
  CXX=clang++ \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  cd / ; rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/aiter*.whl

#
# Transformer engine
#
ENV NVTE_FRAMEWORK pytorch
ENV NVTE_ROCM_ARCH gfx90a
ENV NVTE_AOTRITON_PATH /opt/aotriton
ENV NVTE_FUSED_ATTN_CK 0

ARG TE_VERSION
RUN $WITH_CONDA; set -eux ; \
  export GPU_TARGETS=gfx90a ; \
  export TARGET_GPUS=MI250X  ; \
  rm -rf /opt/mybuild ; \
  git clone --recursive https://github.com/ROCm/TransformerEngine.git /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev $TE_VERSION ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
  \
  echo '#!/bin/bash -eux' > clang++ ; \
  echo 'exec $ROCM_PATH/llvm/bin/clang++ -Wno-c++11-narrowing $@' >> clang++ ; \
  chmod +x clang++ ; \
  export PATH=$(pwd):$PATH ; \
  \
  sed -i 's/-Werror//g' /opt/mybuild/3rdparty/aotriton/third_party/triton/CMakeLists.txt ; \
  sed -i 's/_TEprivate//g' /opt/mybuild/transformer_engine/common/CMakeLists.txt ; \
  sed -i 's/-Wno-gnu-line-marker -Wunused-variable/-Wno-gnu-line-marker -Wno-invalid-constexpr -Wunused-variable/g' /opt/mybuild/transformer_engine/common/ck_fused_attn/CMakeLists.txt ; \
  CC=clang \
    CXX=clang++ \
    TORCH_DONT_CHECK_COMPILER_ABI=1 \
    pip wheel --no-deps --verbose -e . -w /opt/wheels ; \
  rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  pip install \
    /opt/wheels/transformer_engine-*.whl

# force all RCCL streams to be high priority
ENV TORCH_NCCL_HIGH_PRIORITY 1
ENV RCCL_MSCCL_ENABLE 0

RUN $WITH_CONDA; set -eux ; \
  CC=gcc-12 \
  CXX=g++-12 \
  pip3 install \
    scipy \
    einops \
    flask-restful \
    nltk \
    pytest \
    pytest-cov \
    pytest_mock \
    pytest-csv \
    pytest-random-order \
    sentencepiece \
    wrapt \
    zarr \
    wandb \
    tensorstore==0.1.45 \
    pytest_mock \
    pybind11 \
    setuptools \
    datasets \
    tiktoken \
    pynvml

RUN $WITH_CONDA; set -eux ; \
  pip3 install "huggingface_hub[cli]"

# Is this needed? 
# RUN $WITH_CONDA; set -eux ; \
#   python3 -m nltk.downloader punkt_tab

ENV CAUSAL_CONV1D_FORCE_BUILD=TRUE
ENV MAMBA_FORCE_BUILD=TRUE
ENV HIP_ARCHITECTURES=gfx90a

RUN $WITH_CONDA; set -eux ; \
  rm -rf /opt/mybuild ;\
  git clone https://github.com/Dao-AILab/causal-conv1d /opt/mybuild ; \
  cd /opt/mybuild ; \
  CC=gcc-12 \
  CXX=g++-12 \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  cd / ; rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  rm -rf /opt/mybuild ;\
  git clone https://github.com/state-spaces/mamba /opt/mybuild ; \
  cd /opt/mybuild ; \
  CC=gcc-12 \
  CXX=g++-12 \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  cd / ; rm -rf /opt/mybuild

# For transformer engine.
ENV NVTE_USE_HIPBLASLT=1

RUN $WITH_CONDA; set -eux ; \
  rm -rf /opt/mybuild ;\
  git clone https://github.com/caaatch22/grouped_gemm.git /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout rocm ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
  CC=gcc-12 \
  CXX=g++-12 \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  cd / ; rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/causal_conv1d-*.whl ; \
  true

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/mamba_ssm-*.whl ; \
  true

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/grouped_gemm-*.whl ; \
  true

ARG MEGATRON_VERSION
RUN $WITH_CONDA; set -eux ; \
  rm -rf /opt/mybuild ;\
  git clone https://github.com/ROCm/Megatron-LM.git /opt/mybuild ; \
  cd /opt/mybuild ; \
  git checkout -b mydev $MEGATRON_VERSION ; \
  git submodule sync ; \
  git submodule update --init --recursive --jobs 0 ; \
  CC=gcc-12 \
  CXX=g++-12 \
    python3 setup.py bdist_wheel --dist-dir=/opt/wheels ; \
  cd / ; rm -rf /opt/mybuild

RUN $WITH_CONDA; set -eux ; \
  pip install /opt/wheels/megatron_core-*.whl ; \
  true

#Use Pytorch triton LLVM version
ENV LLVM_BUILD_DIR=/opt/llvm-project-final/build
ENV LLVM_INCLUDE_DIRS=$LLVM_BUILD_DIR/include
ENV LLVM_LIBRARY_DIR=$LLVM_BUILD_DIR/lib
ENV LLVM_SYSPATH=$LLVM_BUILD_DIR

RUN $WITH_CONDA; set -eux ; \
    pip install /opt/wheels/triton-*git${TRITON_FINAL_VERSION:0:8}*.whl
    