# Use spaces instead of tabs
.RECIPEPREFIX := $(.RECIPEPREFIX)  

base := $(shell pwd)
common_files := $(shell find $$(pwd)/common -name Dockerfile.*)
#
# List all images here
#
.PHONY: all alphafold pytorch mpi4py tensorflow

all: alphafold mpi4py pytorch tensorflow rocm jax
  echo "Built all"

#
# List all variation for each image here
#
alphafold: alphafold/build-rocm-6.2.4-python-3.10-alphafold-f251de6.done

mpi4py_deps := mpi4py/build-rocm-6.1.3-python-3.12-mpi4py-3.1.6.done
mpi4py_deps += mpi4py/build-rocm-6.1.3-python-3.12-mpi4py-4.1.0.done
mpi4py: $(mpi4py_deps)

pytorch_deps := pytorch/build-rocm-5.7.3-python-3.12-pytorch-v2.2.2.done
pytorch_deps += pytorch/build-rocm-6.0.3-python-3.12-pytorch-v2.3.1.done
pytorch_deps += pytorch/build-rocm-6.1.3-python-3.12-pytorch-v2.4.1.done
pytorch_deps += pytorch/build-rocm-6.2.0-python-3.10-pytorch-v2.3.0.done
pytorch_deps += pytorch/build-rocm-6.2.0-python-3.12-pytorch-20240801-vllm-c7a3a47.done
pytorch_deps += pytorch/build-rocm-6.2.1-python-3.12-pytorch-20240918-vllm-4075b35.done
pytorch_deps += pytorch/build-rocm-6.2.3-python-3.12-pytorch-v2.5.1.done
pytorch_deps += pytorch/build-rocm-6.2.4-python-3.12-pytorch-v2.5.1.done
pytorch_deps += pytorch/build-rocm-6.2.4-python-3.12-pytorch-v2.6.0.done
pytorch_deps += pytorch/build-rocm-6.2.4-python-3.12-pytorch-v2.7.0.done
pytorch_deps += pytorch/build-rocm-6.2.4-python-3.12-pytorch-v2.7.1.done
pytorch_deps += pytorch/build-rocm-6.2.4-python-3.12-pytorch-v2.7.1-te.done
pytorch: $(pytorch_deps)

tensorflow: tensorflow/build-rocm-6.2.3-python-3.10-tensorflow-2.16.2-horovod-0.28.1.done

rocm_deps := rocm/build-rocm-5.7.3.done
rocm_deps += rocm/build-rocm-6.0.3.done
rocm_deps += rocm/build-rocm-6.1.3.done
rocm_deps += rocm/build-rocm-asan-6.1.3.done
rocm_deps += rocm/build-rocm-6.2.0.done
rocm_deps += rocm/build-rocm-6.2.1.done
rocm_deps += rocm/build-rocm-6.2.2.done
rocm_deps += rocm/build-rocm-asan-6.2.2.done
rocm_deps += rocm/build-rocm-6.2.3.done
rocm_deps += rocm/build-rocm-asan-6.2.3.done
rocm_deps += rocm/build-rocm-6.2.4.done
rocm_deps += rocm/build-rocm-asan-6.2.4.done
rocm: $(rocm_deps)

jax_deps := jax/build-rocm-6.2.0-python-3.12-jax-0.4.28.done
jax_deps += jax/build-rocm-6.2.4-python-3.12-jax-0.4.35.done
jax_deps += jax/build-rocm-6.2.4-python-3.12-jax-0.5.0.done
jax_deps += jax/build-rocm-6.2.4-python-3.12-jax-0.5.1.done
jax_deps += jax/build-rocm-6.2.4-python-3.12-jax-community-0.5.0.done
jax: $(jax_deps)

#
# Generic recipe 
#
%.done: %.sh %.docker $(common_files)
  set -eu ; \
  app=$$(dirname $<) ; \
  rp=$$(realpath $<) ; \
  export RES=$$(realpath $@) ; \
  cd $$(dirname $$rp) ; \
  t=$$(basename $$rp | sed 's#^build-##g' | sed 's#.sh$$##g') ; \
  export TAG="lumi/lumi-$$app:$$t" ; \
  export DOCKERFILE=build-$$t.docker ; \
  export DOCKERFILE_TMP=.tmp-build-$$t.docker ; \
  export LOG=build-$$t.log ; \
  $$rp
  
