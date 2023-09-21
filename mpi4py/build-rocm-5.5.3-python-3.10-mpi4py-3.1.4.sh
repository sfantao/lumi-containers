#!/bin/bash -eux 
set -o pipefail

PYTHON_VERSION='3.10'

cat \
  ../common/Dockerfile.header \
  ../common/Dockerfile.rocm-5.4.5  \
  ../common/Dockerfile.miniconda \
  $DOCKERFILE \
  ../common/Dockerfile.cupy \
  ../common/Dockerfile.mpi4py \
  ../common/Dockerfile.osu \
  > .Dockerfile

$DOCKERBUILD \
  --build-arg SERVER_PORT=$SERVER_PORT \
  --build-arg PYTHON_VERSION=$PYTHON_VERSION \
  --progress=plain -t $TAG . 2>&1 | tee $LOG

echo "$TAG" > $RES
