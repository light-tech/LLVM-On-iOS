# Script to build LLVM for macOS
# Execute in top `llvm-project` folder

DOWNLOADS=~/Downloads

rm -rf build_macos
mkdir build_macos
cd build_macos

# Generate configuration for building for MacOS
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
  -DFFI_INCLUDE_DIR=$DOWNLOADS/libffi/Release-macos/include/ffi \
  -DFFI_LIBRARY_DIR=$DOWNLOADS/libffi/Release-macos \
  -DLLVM_TARGET_ARCH="x86_64" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$DOWNLOADS/LLVM-macOS \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_MAKE_PROGRAM=$DOWNLOADS/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .
