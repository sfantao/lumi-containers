cd /
tar -cf  \
  ~/amd/scratch/cpe-23.09.tar \
  opt/cray/libfabric/1.15.2.0/ \
  opt/cray/pe/mpich/8.1.27/ofi/crayclang/14.0 \
  opt/cray/pe/mpich/8.1.27/gtl/lib/libmpi_gtl_hsa.* \
  usr/lib64/libcxi.so*
