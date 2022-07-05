# Build LLVM XCFramework
#
# The script arguments are the platforms to build
#
# We assume that all required build tools (CMake, ninja, etc.) are either installed and accessible in $PATH
# or are available locally within this repo root at $REPO_ROOT/tools/bin (building on VSTS).

PLATFORMS_TO_BUILD=( "$@" )

# List of platforms-architecture that we support
# iphoneos iphonesimulator maccatalyst
# AVAILABLE_PLATFORMS=(iphoneos iphonesimulator-arm64 maccatalyst-arm64)

# Constants
export REPO_ROOT=`pwd`

### Setup $BASE_PLATFORM, $ARCH and $LIBFFI_INSTALL_DIR from platform-architecture string
function setup_variables() {
	local PLATFORM_ARCH=$1

	case $PLATFORM_ARCH in
		"iphoneos")
			ARCH="arm64"
			BASE_PLATFORM=$PLATFORM_ARCH;;

		"iphonesimulator")
			ARCH="x86_64"
			BASE_PLATFORM="iphonesimulator";;

		"iphonesimulator-arm64")
			ARCH="arm64"
			BASE_PLATFORM="iphonesimulator";;

		"maccatalyst")
			ARCH="x86_64"
			BASE_PLATFORM="maccatalyst";;

		"maccatalyst-arm64")
			ARCH="arm64"
			BASE_PLATFORM="maccatalyst";;

		*)
			echo "Unknown or missing platform!"
			exit 1;;
	esac

	LIBFFI_INSTALL_DIR=$REPO_ROOT/libffi/Release-$BASE_PLATFORM
}

# Build libffi for a given platform
function build_libffi() {
	local PLATFORM=$1
	setup_variables $PLATFORM
	local LIBFFI_BUILD_DIR=$REPO_ROOT/libffi

	echo "Build libffi for $PLATFORM"

	cd $REPO_ROOT
	test -d libffi || git clone https://github.com/libffi/libffi.git
	cd libffi

	case $PLATFORM in
		"iphoneos")
			SDK_ARG=(-sdk $BASE_PLATFORM);;

		"iphonesimulator"|"iphonesimulator-arm64")
			SDK_ARG=(-sdk $BASE_PLATFORM -arch $ARCH);;

		"maccatalyst"|"maccatalyst-arm64")
			SDK_ARG=(-arch $ARCH);; # Do not set SDK_ARG

		*)
			echo "Unknown or missing platform!"
			exit 1;;
	esac

	# xcodebuild -list
	# Note that we need to run xcodebuild twice
	# The first run generates necessary headers whereas the second run actually compiles the library
	for r in {1..2}; do
		xcodebuild -scheme libffi-iOS ${SDK_ARG[@]} -configuration Release SYMROOT="$LIBFFI_BUILD_DIR" >/dev/null 2>/dev/null
	done

	lipo -info $LIBFFI_INSTALL_DIR/libffi.a
}

function get_llvm_src() {
	#git clone --single-branch --branch release/14.x https://github.com/llvm/llvm-project.git

	wget https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.0/llvm-project-14.0.0.src.tar.xz
	tar xzf llvm-project-14.0.0.src.tar.xz
	mv llvm-project-14.0.0.src llvm-project
}

# Build LLVM for a given iOS platform
# Assumptions:
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-*
function build_llvm() {
	local PLATFORM=$1
	local LLVM_DIR=$REPO_ROOT/llvm-project
	local LLVM_INSTALL_DIR=$REPO_ROOT/LLVM-$PLATFORM
	setup_variables $PLATFORM

	echo "Build llvm for $PLATFORM"

	cd $REPO_ROOT
	test -d llvm-project || get_llvm_src
	cd llvm-project
	rm -rf build
	mkdir build
	cd build

	# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
	# ;lld;libcxx;libcxxabi
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
		-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake)

	case $PLATFORM in
		"iphoneos")
			CMAKE_ARGS+=(-DLLVM_TARGET_ARCH=$ARCH);;

		"iphonesimulator"|"iphonesimulator-arm64")
			SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT);;

		"maccatalyst"|"maccatalyst-arm64")
			SYSROOT=`xcodebuild -version -sdk macosx Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
				-DCMAKE_C_FLAGS="-target $ARCH-apple-ios14.1-macabi" \
				-DCMAKE_CXX_FLAGS="-target $ARCH-apple-ios14.1-macabi");;

		*)
			echo "Unknown or missing platform!"
			exit 1;;
	esac

	CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH)

	# https://www.shell-tips.com/bash/arrays/
	# https://www.lukeshu.com/blog/bash-arrays.html
	printf 'CMake Argument: %s\n' "${CMAKE_ARGS[@]}"

	# Generate configuration for building for iOS Target (on MacOS Host)
	# Note: AArch64 = arm64
	# Note: We have to use include/ffi subdir for libffi as the main header ffi.h
	# includes <ffi_arm64.h> and not <ffi/ffi_arm64.h>. So if we only use
	# $DOWNLOADS/libffi/Release-iphoneos/include for FFI_INCLUDE_DIR
	# the platform-specific header would not be found!
	cmake "${CMAKE_ARGS[@]}" ../llvm >/dev/null 2>/dev/null

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

	echo "Prepare LLVM for $PLATFORM"
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
	cp -r $LIBFFI_INSTALL_DIR/include/ffi ./include/
	cp $LIBFFI_INSTALL_DIR/libffi.a ./lib/

	# Combine all *.a into a single llvm.a for ease of use
	libtool -static -o llvm.a lib/*.a

	# Remove unnecessary lib files if packaging
	rm -rf lib/*.a
}

for p in ${PLATFORMS_TO_BUILD[@]}; do
	echo "Build LLVM library for $p"

	build_libffi $p && build_llvm $p && prepare_llvm $p
done


