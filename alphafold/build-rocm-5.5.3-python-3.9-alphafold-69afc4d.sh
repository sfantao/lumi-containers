#!/bin/bash -eux 
set -o pipefail

PYTHON_VERSION='3.10'
JAX_VERSION='0.4.13'
ALPHAFOLD_VERSION='69afc4d'
ARIA2_VERSION='1.36.0'
HHSUITE_VERSION='3.3.0'
OPENMM_VERSION='8.0.0'
OPENMM_HIP_VERSION='1631e8d'

cat \
  ../common/Dockerfile.header \
  ../common/Dockerfile.rocm-5.5.3  \
  ../common/Dockerfile.miniconda \
  $DOCKERFILE \
  > .Dockerfile

$DOCKERBUILD \
  --build-arg SERVER_PORT=$SERVER_PORT \
  --build-arg PYTHON_VERSION=$PYTHON_VERSION \
  --build-arg JAX_VERSION=$JAX_VERSION \
  --build-arg ALPHAFOLD_VERSION=$ALPHAFOLD_VERSION \
  --build-arg ARIA2_VERSION=$ARIA2_VERSION \
  --build-arg HHSUITE_VERSION=$HHSUITE_VERSION \
  --build-arg OPENMM_VERSION=$OPENMM_VERSION \
  --build-arg OPENMM_HIP_VERSION=$OPENMM_HIP_VERSION \
  --progress=plain -t $TAG . 2>&1 | tee $LOG

echo "$TAG" > $RES