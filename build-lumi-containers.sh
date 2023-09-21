#!/bin/bash -e

target=all
procs=4

#
# Change default target if that has been provided.
#
if [ $# -eq 2 ] ; then
  target=$1
  procs=$2
fi

#
# Start server to make available proprietary libraries to build against that can't reside
# in the resulting images.
#
export SERVER_PORT=57698

export DOCKERBUILD="docker build \
                      -f .Dockerfile \
                      --ulimit nofile=32000:32000 \
                      --network=host \
                      --build-arg SERVER_PORT=$SERVER_PORT "

if [ ! -f server-files.pid ] ; then
  echo "Starting server..."
  ml python
  python3 -m http.server --bind localhost --directory $(pwd)/server-files $SERVER_PORT &> server-files.log &
  echo "$!" > server-files.pid
  echo "Server has started!"
fi

#
# Build recipes
#

echo "Starting image building..."
make -j$procs $target
echo "Done building images..."

#
# Kill server
#
echo "Stopping server..."
p=$(cat server-files.pid)
kill $p || true
wait $p || true
rm -rf server-files.pid
echo "Server has stopped!"

#
# Close
#
echo " ------------------------------------ "
echo " Recipes build completed successfully "
echo " ------------------------------------ "

#
# Upstream and test images.
#
LUMI_TEST_FOLDER="/pfs/lustrep2/scratch/project_462000125/samantao/containers-test"
Nodes=4
echo "test.sbatch" > .all-test-files
cat > test.sbatch << EOF
#!/bin/bash -e
#SBATCH -J lumi-container-test
#SBATCH -p standard-g
#SBATCH --threads-per-core 1
#SBATCH --exclusive 
#SBATCH -N $Nodes 
#SBATCH --gpus $((Nodes*8)) 
#SBATCH -t 0:30:00 
#SBATCH --mem 0
#SBATCH -o test.out
#SBATCH -e test.err

set -o pipefail
export NCCL_SOCKET_IFNAME=hsn0,hsn1,hsn2,hsn3

#
# Execute examples
#

c=fe
#
# Bind mask for one and  thread per core
#
MYMASKS1="0x\${c}000000000000,0x\${c}00000000000000,0x\${c}0000,0x\${c}000000,0x\${c},0x\${c}00,0x\${c}00000000,0x\${c}0000000000"
MYMASKS2="0x\${c}00000000000000\${c}000000000000,0x\${c}00000000000000\${c}00000000000000,0x\${c}00000000000000\${c}0000,0x\${c}00000000000000\${c}000000,0x\${c}00000000000000\${c},0x\${c}00000000000000\${c}00,0x\${c}00000000000000\${c}00000000,0x\${c}00000000000000\${c}0000000000"

export SCMD="srun \
  --jobid 4577206 \
  -N $Nodes \
  -n $((Nodes*8)) \
  --cpu-bind=mask_cpu:\$MYMASKS1 \
  --gpus $((Nodes*8)) \
  singularity exec \
    -B /var/spool/slurmd:/var/spool/slurmd \
    -B /opt/cray:/opt/cray \
    -B /usr/lib64/libcxi.so.1:/usr/lib64/libcxi.so.1"
EOF

if [[ "$target" == "all" ]] ; then
  files=$(ls -1 */*.done)
else
  files=$(ls -1 $target/*.done)
fi

docker login
for i in $files ; do
  while read -r line; do 
    # project filename test_filename local_tag remote_tag sif_file_part1 sif_file_part2
    project=$(dirname $i)
    filename=$(basename $i)
    test_filename=${filename%.done}.test

    #
    # Push images
    #
    local_tag=$line
    remote_tag=sfantao/$line
    docker tag $local_tag $remote_tag
    docker push $remote_tag
    
    #
    # Build singularity images remotely if they do not exist.
    #
    hash=$(docker images $local_tag | head -n2 | tail -n1 | awk '{print $3;}')
    sif1="$LUMI_TEST_FOLDER/$(echo $local_tag | sed 's/:/-/g' )-dockerhash-"
    sif2="$hash.sif"
    sif="${sif1}${sif2}"

    ssh lumi "bash -c 'set -ex ; if [ -f ${sif} ] ; then echo "${sif1} already exists!" ; else rm -rf ${sif1}* ; singularity build ${sif} docker://$remote_tag ; fi'"

    #
    # Add entry to test script.
    #
    echo "$project/$test_filename" >> .all-test-files
    cat >> test.sbatch << EOF


    test=\$(realpath $project/$test_filename)
    sif=\$(realpath $sif)

    chmod +x \$test

    cd $project
    \$test \$sif |& tee $test_filename.log
    if [ \$? -eq 0 ] ; then
      echo "-------------------"
      echo "Test success!!! --> $local_tag (\$sif)"
      echo "-------------------"
    else
      echo "###################"
      echo "###################"
      echo "###################"
      echo "Test FAILED!!! --> $local_tag (\$sif)"
      echo "###################"
      echo "###################"
      echo "###################"
    fi
    \cd -


EOF
  done < $i
done

rm -rf test.tar 
tar -cf test.tar $(cat .all-test-files)
scp test.tar lumi:$LUMI_TEST_FOLDER
ssh lumi "bash -c 'set -ex ; cd $LUMI_TEST_FOLDER; rm -rf runtests ; mkdir runtests ; cd runtests; tar -xf ../test.tar ; bash test.sbatch'"
