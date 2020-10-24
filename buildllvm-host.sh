# Assuming cmake was added to $PATH
# Assuming ninja was downloaded and extracted to ~/Downloads

DOWNLOADS=~/Downloads

# Generate configuration for building for Host (for use in iOS simulator)
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$DOWNLOADS/LLVM-Host \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_MAKE_PROGRAM=$DOWNLOADS/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .