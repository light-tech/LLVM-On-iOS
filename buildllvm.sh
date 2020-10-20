# Assuming cmake was added to $PATH
# Assuming ninja was downloaded and extracted to ~/Downloads

DOWNLOADS=~/Downloads

# Generate configuration for building for iOS Target (on MacOS Host)
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang;lld;libcxx;libcxxabi;libunwind" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$DOWNLOADS/llvm \
  -DCMAKE_OSX_ARCHITECTURES="armv7;armv7s;arm64" \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$DOWNLOADS/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .