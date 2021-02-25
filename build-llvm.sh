# Script to build LLVM for iOS Device
# Assumptions:
#  * Run at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-maccatalyst

PLATFORM=$1
REPO_DIR=`pwd`
LLVM_DIR=$REPO_DIR/llvm-project
LLVM_INSTALL_DIR=$REPO_DIR/LLVM-$PLATFORM

case $PLATFORM in
  "iOS")
	echo "Build LLVM for iOS device"
    ARCH="arm64"
    LIBFFI_DIR="$REPO_DIR/libffi/Release-iphoneos"
    EXTRA_CMAKE_ARGS="-DLLVM_TARGET_ARCH='$ARCH'";;
  "iOS-Sim")
    echo "Build LLVM for iOS simulator"
    ARCH="x86_64"
    LIBFFI_DIR="$REPO_DIR/libffi/Release-iphonesimulator"
    # Use xcodebuild -showsdks to find out the available SDK name
    SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
    EXTRA_CMAKE_ARGS=-DCMAKE_OSX_SYSROOT=$SYSROOT;;
  "macOS")
    echo "Build LLVM for MacOS"
    ARCH="x86_64"
    LIBFFI_DIR="$REPO_DIR/libffi/Release-maccatalyst"
    # Use xcodebuild -showsdks to find out the available SDK name
    SYSROOT=`xcodebuild -version -sdk macosx Path`
    EXTRA_CMAKE_ARGS="-DCMAKE_OSX_SYSROOT=$SYSROOT";;
  *)
    echo "Unknown or missing platform!"
    ARCH=x86_64
	exit 1;;
esac

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
# the platform-specific header would not be found! ;lld;libcxx;libcxxabi
cmake -G "Ninja" \
  -DLLVM_ENABLE_PROJECTS="clang" \
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
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
  -DCMAKE_MAKE_PROGRAM=$REPO_DIR/ninja \
  $EXTRA_CMAKE_ARGS ../llvm

# When building for real iOS device, we need to open `build_ios/CMakeCache.txt` at this point, search for and FORCIBLY change the value of **HAVE_FFI_CALL** to **1**.
# For some reason, CMake did not manage to determine that `ffi_call` was available even though it really is the case.
# Without this, the execution engine is not built with libffi at all.
sed -i.bak 's/^HAVE_FFI_CALL:INTERNAL=/HAVE_FFI_CALL:INTERNAL=1/g' CMakeCache.txt

# Build
cmake --build .

# Install libs
cmake --install .
