#if 0
/opt/rocm/llvm/bin/clang++ \
    -std=c++20 \
    -I${ROCM_PATH}/include \
    -D__HIP_PLATFORM_AMD__ \
    -fPIC -shared -g -O3 \
    -L${ROCM_PATH}/lib \
    -lamdhip64 \
    -o libpreload-me.so preload-me.cpp
exit 0
#endif

#include <stdio.h>
#include <dlfcn.h>
#include <cassert>
#include <string>
#include <fstream>

#define hipError_t int
#define hipSuccess 0
#define hipErrorNotSupported 801

extern "C" {
    hipError_t hipGetDevice (int* device);
    hipError_t hipGetDeviceCount (int* count);
}

namespace {


// Initializes the symbol of the original runtime symbol and return 0 if success
template<typename T>
int lazy_init(T *&fptr, const char *name) {
    void *&ptr = reinterpret_cast<void *&>(fptr);

    if (ptr) return 0;

    ptr = dlsym(RTLD_NEXT, name);

    assert(ptr);

    return ptr ? 0 : -1;
}

hipError_t (*hipMemGetInfo_orig)(size_t *, size_t *) = nullptr;

}

extern "C" {
hipError_t 	hipMemGetInfo (size_t* free, size_t* total){

  if(lazy_init(hipMemGetInfo_orig, "hipMemGetInfo")) return hipErrorNotSupported;

  hipError_t ret;
  ret = hipMemGetInfo_orig(free, total);
  if(ret) return ret;

  int device;
  int count;
  
  ret = hipGetDeviceCount(&count);
  if(ret) return ret;
  
  assert(count == 8 && "The hipMemGetInfo implementation is assuming the 8 GPUs in a LUMI node are visible to each process");
  
  ret = hipGetDevice(&device);
  if(ret) return ret;
  
  assert(device >= 0 && device < 8 && "Device ID expected in the range [0,8[");
  
  // Read the data from the KFD.
  int logical_device = device + 4;
  
  std::string fileName = std::string("/sys/class/kfd/kfd/topology/nodes/") + std::to_string(logical_device) + std::string("/mem_banks/0/used_memory");  
  
	std::ifstream file;
	file.open(fileName);
	if (!file) return hipErrorNotSupported;

  std::string deviceSize;	
	size_t deviceMemSize;

	file >> deviceSize;
	file.close();         
	        
  if ((deviceMemSize=strtol(deviceSize.c_str(),NULL,10)))
	  *free = *total - deviceMemSize;
	else
    return hipErrorNotSupported;
	
  return hipSuccess;
}

}
