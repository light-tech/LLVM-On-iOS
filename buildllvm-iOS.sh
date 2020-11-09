# Script to build LLVM for iOS Device
# Execute in top `llvm-project` folder

DOWNLOADS=~/Downloads

rm -rf build_ios
mkdir build_ios
cd build_ios

# Generate configuration for building for iOS Target (on MacOS Host)
# Note: AArch64 = arm64
# Note: We have to use include/ffi subdir for libffi as the main header ffi.h
# includes <ffi_arm64.h> and not <ffi/ffi_arm64.h>. So if we only use
# $DOWNLOADS/libffi/Release-iphoneos/include for FFI_INCLUDE_DIR
# the platform-specific header would not be found!
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang;lld;libcxx;libcxxabi" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_BUILD_TOOLS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_THREADS=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF \
  -DLLVM_ENABLE_EH=OFF \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_FFI=ON \
  -DFFI_INCLUDE_DIR=$DOWNLOADS/libffi/Release-iphoneos/include/ffi \
  -DFFI_LIBRARY_DIR=$DOWNLOADS/libffi/Release-iphoneos \
  -DLLVM_TARGET_ARCH="arm64" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$DOWNLOADS/LLVM-iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$DOWNLOADS/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .
