# Script to build LLVM for iOS Simulator
# Execute in top `llvm-project` folder

REPO_DIR=`pwd`
LIBFFI_DIR=$REPO_DIR/libffi/Release-maccatalyst
LLVM_DIR=$REPO_DIR/llvm-project
LLVM_INSTALL_DIR=$REPO_DIR/LLVM-iOS-Sim

wget https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-mac.zip
unzip ninja-mac.zip

# Use xcodebuild -showsdks to find out the available SDK name
SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`

rm -rf build_ios_sim
mkdir build_ios_sim
cd build_ios_sim

# Generate configuration for building for iOS Simulator
# After reading iOS.cmake, one realizes that the key idea (and difference to building for iOS device) is to set
# CMAKE_OSX_SYSROOT for the simulator SDK instead of letting the CMAKE find it.
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
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_SYSROOT=$SYSROOT \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$REPO_DIR/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .
