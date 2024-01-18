#!/bin/bash -eux 
set -o pipefail

PYTHON_VERSION='3.10'
JAX_VERSION='0.4.13'

cat \
  ../common/Dockerfile.header \
  ../common/Dockerfile.rocm-5.6.1  \
  ../common/Dockerfile.miniconda \
  ../common/Dockerfile.aws-ofi-rccl \
  ../common/Dockerfile.rccltest \
  $DOCKERFILE \
  > $DOCKERFILE_TMP

$DOCKERBUILD \
  -f $DOCKERFILE_TMP \
  --build-arg SERVER_PORT=$SERVER_PORT \
  --build-arg PYTHON_VERSION=$PYTHON_VERSION \
  --build-arg JAX_VERSION=$JAX_VERSION \
  --progress=plain -t $TAG . 2>&1 | tee $LOG

echo "$TAG" > $RES
