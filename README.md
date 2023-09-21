# LUMI containers - recipes and build/tests infrastructure.

This repository contains recipes for container images tailored for LUMI for some of the most popular workloads that run on the machine and can leverage containers well.

The images use the Docker format and the included logic allows to build them and generate the corresponding [Singularity](https://docs.sylabs.io/guides/3.5/user-guide/introduction.html) images. 
Also, there are tests that can be used as examples on how to use these containers. 
Typically, these images are prepared to be run like:
```
#
# If GPU-aware MPI is needed
#
export MPICH_GPU_SUPPORT_ENABLED=1

#
# Script to set the application environemnt inside the container.
#
cat > run.sh << EOF
#!/bin/bash -e
cd /myrun
\$WITH_CONDA
set -x
./myapp
EOF
chmod +x run.sh 

#
# For 8 GPUs per node
#
MYMASKS="0xfe000000000000,0xfe00000000000000,0xfe0000,0xfe000000,0xfe,0xfe00,0xfe00000000,0xfe0000000000"
srun \
  -N $Nodes \
  -n $((Nodes*8)) \
  --cpu-bind=mask_cpu:\$MYMASKS \
  --gpus $((Nodes*8)) \
  singularity exec \
    -B /var/spool/slurmd:/var/spool/slurmd \
    -B /opt/cray:/opt/cray \
    -B /usr/lib64/libcxi.so.1:/usr/lib64/libcxi.so.1
    -B $(pwd):/myrun \
    image.sif \
    /myrun/run.sh
```
We recommend using a proxy script to set your environment (e.g. select which GPUs to use per rank). 
There is a variable defined in the images `$WITH_CONDA` that allows one to easily start the relevant conda environments inside the container. 
The images' Python implementation is provided by [Miniconda](https://docs.conda.io/projects/miniconda/en/latest/).

LUMI is CrayEX machine that uses the Cray proprietary programming environment and fabric. 
Therefore, these images are being built against that environment to ensure maximum compatibility between the enviroments inside and outside the containers.
However, given the proprietary nature of the environemnt the images do not store any files from the Cray environment. 
Instead, the build logic makes the relevant files available through a webserver that serves them from `server-files` during the different build steps and remove them at the end.
It is up to the user to make sure they have the right access and licensing in place to use these files and make them available under `server-files` for the builds.
