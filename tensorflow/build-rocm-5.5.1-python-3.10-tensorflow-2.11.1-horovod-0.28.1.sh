#!/bin/bash -eux 
set -o pipefail

PYTHON_VERSION='3.10'
TENSORFLOW_VERSION='2.11.1.550'
HOROVOD_VERSION='0.28.1'
OPENNMT_VERSION='2.32.0'

cat \
  ../common/Dockerfile.header \
  ../common/Dockerfile.rocm-5.5.1  \
  ../common/Dockerfile.miniconda \
  ../common/Dockerfile.aws-ofi-rccl \
  ../common/Dockerfile.rccltest \
  $DOCKERFILE \
  > $DOCKERFILE_TMP

$DOCKERBUILD \
  -f $DOCKERFILE_TMP \
  --build-arg SERVER_PORT=$SERVER_PORT \
  --build-arg PYTHON_VERSION=$PYTHON_VERSION \
  --build-arg TENSORFLOW_VERSION=$TENSORFLOW_VERSION \
  --build-arg HOROVOD_VERSION=$HOROVOD_VERSION \
  --build-arg OPENNMT_VERSION='' \
  --progress=plain -t $TAG . 2>&1 | tee $LOG

$DOCKERBUILD \
  -f $DOCKERFILE_TMP \
  --build-arg SERVER_PORT=$SERVER_PORT \
  --build-arg PYTHON_VERSION=$PYTHON_VERSION \
  --build-arg TENSORFLOW_VERSION=$TENSORFLOW_VERSION \
  --build-arg HOROVOD_VERSION=$HOROVOD_VERSION \
  --build-arg OPENNMT_VERSION=$OPENNMT_VERSION \
  --progress=plain -t $TAG-opennmt-$OPENNMT_VERSION . 2>&1 | tee -a $LOG
  
echo "$TAG" > $RES
echo "$TAG-opennmt-$OPENNMT_VERSION" >> $RES