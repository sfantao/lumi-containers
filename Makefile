# Use spaces instead of tabs
.RECIPEPREFIX +=  

base := $(shell pwd)
common_files := $(shell find $$(pwd)/common -name Dockerfile.*)
#
# List all images here
#
.PHONY: all alphafold pytorch mpi4py tensorflow

all: alphafold mpi4py pytorch tensorflow
  echo "Built all"

#
# List all variation for each image here
#
alphafold: alphafold/build-rocm-5.5.3-python-3.9-alphafold-69afc4d.done

mpi4py: mpi4py/build-rocm-5.5.3-python-3.10-mpi4py-3.1.4.done

pytorch: pytorch/build-rocm-5.5.1-python-3.10-pytorch-v2.0.1.done

tensorflow: tensorflow/build-rocm-5.5.1-python-3.10-tensorflow-2.11.1-horovod-0.28.1.done

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
  export TAG="lumi-$$app:$$t" ; \
  export DOCKERFILE=build-$$t.docker ; \
  export LOG=build-$$t.log ; \
  $$rp
  