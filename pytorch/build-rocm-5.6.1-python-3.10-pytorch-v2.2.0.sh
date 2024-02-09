#!/bin/bash -eux 
set -o pipefail

PYTHON_VERSION='3.10'
PYTORCH_VERSION='2.2.0'

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
  --build-arg PYTORCH_VERSION=$PYTORCH_VERSION \
  --build-arg PYTORCH_DEBUG=0 \
  --build-arg PYTORCH_RELWITHDEBINFO=0 \
  --progress=plain -t $TAG . 2>&1 | tee $LOG

echo "$TAG" > $RES