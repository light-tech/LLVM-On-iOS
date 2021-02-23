# Script to build LLVM for iOS Device
# Assumptions:
#  * Run at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-maccatalyst

REPO_DIR=`pwd`
LIBFFI_DIR=$REPO_DIR/libffi/Release-maccatalyst
LLVM_DIR=$REPO_DIR/llvm-project
LLVM_INSTALL_DIR=$REPO_DIR/LLVM-iOS

# Download and extract ninja
wget https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-mac.zip
unzip ninja-mac.zip

cd llvm-project

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
  -DFFI_INCLUDE_DIR=$LIBFFI_DIR/include/ffi \
  -DFFI_LIBRARY_DIR=$LIBFFI_DIR \
  -DLLVM_TARGET_ARCH="arm64" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$REPO_DIR/ninja \
  ../llvm

# Build
# cmake --build .

# Install libs
# cmake --install .
