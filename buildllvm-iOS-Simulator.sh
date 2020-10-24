# Run in a build folder of the extracted LLVM repo
# Assuming cmake was added to $PATH
# Assuming ninja was downloaded and extracted to ~/Downloads

DOWNLOADS=~/Downloads

# Use xcodebuild -showsdks to find out the available SDK name
SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`

# Generate configuration for building for iOS Simulator
# After reading iOS.cmake, one realizes that the key idea (and difference to building for iOS device) is to set
# CMAKE_OSX_SYSROOT for the simulator SDK instead of letting the CMAKE find it.
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$DOWNLOADS/LLVM-iOS-Sim \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_SYSROOT=$SYSROOT \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$DOWNLOADS/ninja \
  ../llvm

# Build
cmake --build .

# Install libs
cmake --install .
