# Build LLVM XCFramework
# The script arguments are the platforms to build

PLATFORMS=( "$@" )

# Constants
export REPO_ROOT=`pwd`
export PATH=$PATH:$REPO_ROOT/tools/bin

# Download various tools such as autoconf, automake and libtool
test -d tools || wget https://github.com/light-tech/LLVM-On-iOS/releases/download/llvm12.0.0/tools.tar.xz
tar xzf tools.tar.xz

# Download and extract ninja
wget https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-mac.zip
unzip ninja-mac.zip

# Build libffi for a given platform
function build_libffi() {
	local PLATFORM=$1
	local LIBFFI_SRC_DIR=$REPO_ROOT/libffi
	local LIBFFI_BUILD_DIR=$REPO_ROOT/libffi

	cd $REPO_ROOT
	test -d libffi || git clone https://github.com/libffi/libffi.git

	case $PLATFORM in
	  "iphoneos"|"iphonesimulator")
		SDK_ARG=(-sdk $PLATFORM);;

	  "maccatalyst")
		SDK="maccatalyst"
		SDK_ARG=();;
		# SDK_ARG=-sdk $SDK # Do not set SDK_ARG

	  *)
		echo "Unknown or missing platform!"
		exit 1;;
	esac

	cd $LIBFFI_SRC_DIR

	# xcodebuild -list
	# Note that we need to run xcodebuild twice
	# The first run generates necessary headers whereas the second run actually compiles the library
	for r in {1..2}; do
		xcodebuild -scheme libffi-iOS ${SDK_ARG[@]} -configuration Release SYMROOT="$LIBFFI_BUILD_DIR" >/dev/null 2>/dev/null
	done
}

# Build LLVM for a given iOS platform
# Assumptions:
#  * Run at this repo root
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-*
function build_llvm() {
	local PLATFORM=$1
	local LLVM_DIR=$REPO_ROOT/llvm-project
	local LLVM_INSTALL_DIR=$REPO_ROOT/LLVM-$PLATFORM
	local LIBFFI_INSTALL_DIR=$REPO_ROOT/libffi/Release-$PLATFORM

	cd $REPO_ROOT
	test -d llvm-project || git clone --single-branch --branch release/12.x https://github.com/llvm/llvm-project.git
	cd llvm-project
	rm -rf build
	mkdir build
	cd build

	# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
	local CMAKE_ARGS=(-G "Ninja" \
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
	  -DFFI_INCLUDE_DIR=$LIBFFI_INSTALL_DIR/include/ffi \
	  -DFFI_LIBRARY_DIR=$LIBFFI_INSTALL_DIR \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR \
	  -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake \
	  -DCMAKE_MAKE_PROGRAM=$REPO_ROOT/ninja)

	case $PLATFORM in
	  "iphoneos")
		echo "Build LLVM for iOS device"
		ARCH="arm64"
		CMAKE_ARGS+=("-DLLVM_TARGET_ARCH='$ARCH'");;

	  "iphonesimulator")
		echo "Build LLVM for iOS simulator"
		ARCH="x86_64"
		# Use xcodebuild -showsdks to find out the available SDK name
		SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
		CMAKE_ARGS+=("-DCMAKE_OSX_SYSROOT=$SYSROOT");;

	  "maccatalyst")
		echo "Build LLVM for MacOS"
		ARCH="x86_64"
		# Use xcodebuild -showsdks to find out the available SDK name
		SYSROOT=`xcodebuild -version -sdk macosx Path`
		CMAKE_ARGS+=("-DCMAKE_OSX_SYSROOT=$SYSROOT");; # "-DCMAKE_C_FLAGS=-target x86_64-apple-ios14.1-macabi" "-DCMAKE_CXX_FLAGS=-target x86_64-apple-ios14.1-macabi");;

	  *)
		echo "Unknown or missing platform!"
		ARCH=x86_64
		exit 1;;
	esac

	CMAKE_ARGS+=("-DCMAKE_OSX_ARCHITECTURES='$ARCH'")

	echo "Running CMake with " ${#CMAKE_ARGS[@]} "arguments"
	for i in ${!CMAKE_ARGS[@]}; do
		echo ${CMAKE_ARGS[$i]}
	done

	# Generate configuration for building for iOS Target (on MacOS Host)
	# Note: AArch64 = arm64
	# Note: We have to use include/ffi subdir for libffi as the main header ffi.h
	# includes <ffi_arm64.h> and not <ffi/ffi_arm64.h>. So if we only use
	# $DOWNLOADS/libffi/Release-iphoneos/include for FFI_INCLUDE_DIR
	# the platform-specific header would not be found! ;lld;libcxx;libcxxabi
	case $PLATFORM in
	  "iphoneos"|"iphonesimulator")
			cmake ${CMAKE_ARGS[@]} ../llvm >/dev/null 2>/dev/null;;

	  "maccatalyst")
			cmake ${CMAKE_ARGS[@]} -DCMAKE_C_FLAGS="-target x86_64-apple-ios14.1-macabi" -DCMAKE_CXX_FLAGS="-target x86_64-apple-ios14.1-macabi" ../llvm >/dev/null 2>/dev/null;;
	esac

	# When building for real iOS device, we need to open `build_ios/CMakeCache.txt` at this point, search for and FORCIBLY change the value of **HAVE_FFI_CALL** to **1**.
	# For some reason, CMake did not manage to determine that `ffi_call` was available even though it really is the case.
	# Without this, the execution engine is not built with libffi at all.
	sed -i.bak 's/^HAVE_FFI_CALL:INTERNAL=/HAVE_FFI_CALL:INTERNAL=1/g' CMakeCache.txt

	# Build
	cmake --build . >/dev/null 2>/dev/null

	# Install libs
	cmake --install . >/dev/null 2>/dev/null
}

# Prepare the LLVM built for usage in Xcode
function prepare_llvm() {
	local PLATFORM=$1
	local LIBFFI_BUILD_DIR=$REPO_ROOT/libffi/Release-$PLATFORM

	cd $REPO_ROOT/LLVM-$PLATFORM

	# Remove unnecessary executables and support files
	rm -rf bin libexec share

	# Move unused stuffs in lib to a temporary lib2 (restored when necessary)
	mkdir lib2
	mv lib/cmake lib2/
	mv lib/*.dylib lib2/
	mv lib/libc++* lib2/
	rm -rf lib2 # Comment this if you want to keep

	# Copy libffi
	cp -r $LIBFFI_BUILD_DIR/include/ffi ./include/
	cp $LIBFFI_BUILD_DIR/libffi.a ./lib/

	# Combine all *.a into a single llvm.a for ease of use
	libtool -static -o llvm.a lib/*.a

	# Remove unnecessary lib files if packaging
	rm -rf lib/*.a
}

FRAMEWORKS_ARGS=()
for p in ${PLATFORMS[@]}; do
    echo "Build LLVM for $p"
    build_libffi $p
    build_llvm $p
    prepare_llvm $p

	cd $REPO_ROOT
	FRAMEWORKS_ARGS+=("-library" "LLVM-$p/llvm.a" "-headers" "LLVM-$p/include")
    tar -cJf LLVM-$p.tar.xz LLVM-$p/
    echo "Create clang support headers archive"
    tar -cJf Lib-Clang-$p.tar.xz LLVM-$p/lib/clang/
done

echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output LLVM.xcframework
tar -cJf LLVM.xcframework.tar.xz LLVM.xcframework
