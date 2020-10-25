# Script to build LLVM for iOS Simulator
# Execute in top `llvm-project` folder

DOWNLOADS=~/Downloads

# Use xcodebuild -showsdks to find out the available SDK name
SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`

rm -rf build_ios_sim
mkdir build_ios_sim
cd build_ios_sim

# Generate configuration for building for iOS Simulator
# After reading iOS.cmake, one realizes that the key idea (and difference to building for iOS device) is to set
# CMAKE_OSX_SYSROOT for the simulator SDK instead of letting the CMAKE find it.
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_THREADS=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF \
  -DLLVM_ENABLE_EH=ON \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_TERMINFO=OFF \
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
