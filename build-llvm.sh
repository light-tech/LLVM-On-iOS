# Build LLVM XCFramework
#
# The script arguments are the platforms to build
#
# We assume that all required build tools (CMake, ninja, etc.) are either installed and accessible in $PATH
# or are available locally within this repo root at $REPO_ROOT/tools/bin (building on GitHub Action).

# Assume that this script is source'd at this repo root
export REPO_ROOT=`pwd`

# List of platforms-architecture that we support
# iphoneos iphonesimulator maccatalyst
# AVAILABLE_PLATFORMS=(iphoneos iphonesimulator-arm64 maccatalyst-arm64)

### Setup $targetBasePlatform, $targetArch and $libffiInstallDir from platform-architecture string
setup_variables() {
    local targetPlatformArch=$1

    case $targetPlatformArch in
        "iphoneos")
            targetArch="arm64"
            targetBasePlatform="iphoneos";;

        "iphonesimulator")
            targetArch="x86_64"
            targetBasePlatform="iphonesimulator";;

        "iphonesimulator-arm64")
            targetArch="arm64"
            targetBasePlatform="iphonesimulator";;

        "maccatalyst")
            targetArch="x86_64"
            targetBasePlatform="maccatalyst";;

        "maccatalyst-arm64")
            targetArch="arm64"
            targetBasePlatform="maccatalyst";;

        *)
            echo "Unknown or missing platform!"
            exit 1;;
    esac

    libffiInstallDir=$REPO_ROOT/libffi/Release-$targetBasePlatform
}

# Build libffi for a given platform
build_libffi() {
    local targetPlatformArch=$1
    setup_variables $targetPlatformArch

    echo "Build libffi for $targetPlatformArch"

    cd $REPO_ROOT
    test -d libffi || git clone https://github.com/libffi/libffi.git
    cd libffi

    case $targetPlatformArch in
        "iphoneos")
            xcodeSdkArgs=(-sdk $targetBasePlatform);;

        "iphonesimulator"|"iphonesimulator-arm64")
            xcodeSdkArgs=(-sdk $targetBasePlatform -arch $targetArch);;

        "maccatalyst"|"maccatalyst-arm64")
            xcodeSdkArgs=(-arch $targetArch);; # Do not set SDK

        *)
            echo "Unknown or missing platform!"
            exit 1;;
    esac

    # xcodebuild -list
    # Note that we need to run xcodebuild twice
    # The first run generates necessary headers whereas the second run actually compiles the library
    local libffiBuildDir=$REPO_ROOT/libffi
    for r in {1..2}; do
        xcodebuild -scheme libffi-iOS "${xcodeSdkArgs[@]}" -configuration Release SYMROOT="$libffiBuildDir" >/dev/null 2>/dev/null
    done

    lipo -info $libffiInstallDir/libffi.a
}

get_llvm_src() {
    #git clone --single-branch --branch release/14.x https://github.com/llvm/llvm-project.git

    curl -OL https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.3/llvm-project-15.0.3.src.tar.xz
    tar xzf llvm-project-15.0.3.src.tar.xz
    mv llvm-project-15.0.3.src llvm-project
}

# Prepare the LLVM built for usage in Xcode
prepare_llvm() {
    local targetPlatformArch=$1

    echo "Prepare LLVM for $targetPlatformArch"
    cd $REPO_ROOT/LLVM-$targetPlatformArch

    # Remove unnecessary executables and support files
    rm -rf bin libexec share

    # Move unused stuffs in lib to a temporary lib2 (restored when necessary)
    mkdir lib2
    mv lib/cmake lib2/
    mv lib/*.dylib lib2/
    mv lib/libc++* lib2/
    rm -rf lib2 # Comment this if you want to keep

    # Copy libffi
    cp -r $libffiInstallDir/include/ffi ./include/
    cp $libffiInstallDir/libffi.a ./lib/

    # Combine all *.a into a single llvm.a for ease of use
    libtool -static -o llvm.a lib/*.a

    # Remove unnecessary lib files if packaging
    rm -rf lib/*.a
}

# Build LLVM for a given iOS platform
# Assumptions:
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
#  * libffi is either built or downloaded in relative location libffi/Release-*
build_llvm() {
    local targetPlatformArch=$1

    build_libffi $targetPlatformArch

    local llvmProjectSrcDir=$REPO_ROOT/llvm-project
    local llvmInstallDir=$REPO_ROOT/LLVM-$targetPlatformArch

    setup_variables $targetPlatformArch

    echo "Build llvm for $targetPlatformArch"

    cd $REPO_ROOT
    test -d llvm-project || get_llvm_src
    cd llvm-project
    rm -rf build
    mkdir build
    cd build

    # https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
    # ;lld;libcxx;libcxxabi
    local llvmCmakeArgs=(-G "Ninja" \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
        -DLLVM_BUILD_TOOLS=OFF \
        -DCLANG_BUILD_TOOLS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLVM_ENABLE_ZLIB=OFF \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_ENABLE_THREADS=OFF \
        -DLLVM_ENABLE_UNWIND_TABLES=OFF \
        -DLLVM_ENABLE_EH=OFF \
        -DLLVM_ENABLE_RTTI=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_FFI=ON \
        -DFFI_INCLUDE_DIR=$libffiInstallDir/include/ffi \
        -DFFI_LIBRARY_DIR=$libffiInstallDir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$llvmInstallDir \
        -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake)

    case $targetPlatformArch in
        "iphoneos")
            llvmCmakeArgs+=(-DLLVM_TARGET_ARCH=$targetArch);;

        "iphonesimulator"|"iphonesimulator-arm64")
            llvmCmakeArgs+=(-DCMAKE_OSX_SYSROOT=$(xcodebuild -version -sdk iphonesimulator Path));;

        "maccatalyst"|"maccatalyst-arm64")
            llvmCmakeArgs+=(-DCMAKE_OSX_SYSROOT=$(xcodebuild -version -sdk macosx Path) \
                -DCMAKE_C_FLAGS="-target $targetArch-apple-ios14.1-macabi" \
                -DCMAKE_CXX_FLAGS="-target $targetArch-apple-ios14.1-macabi");;

        *)
            echo "Unknown or missing platform!"
            exit 1;;
    esac

    llvmCmakeArgs+=(-DCMAKE_OSX_ARCHITECTURES=$targetArch)

    # https://www.shell-tips.com/bash/arrays/
    # https://www.lukeshu.com/blog/bash-arrays.html
    printf 'CMake Argument: %s\n' "${llvmCmakeArgs[@]}"

    # Generate configuration for building for iOS Target (on MacOS Host)
    # Note: AArch64 = arm64
    # Note: We have to use include/ffi subdir for libffi as the main header ffi.h
    # includes <ffi_arm64.h> and not <ffi/ffi_arm64.h>. So if we only use
    # $DOWNLOADS/libffi/Release-iphoneos/include for FFI_INCLUDE_DIR
    # the platform-specific header would not be found!
    cmake "${llvmCmakeArgs[@]}" ../llvm || exit -1 # >/dev/null 2>/dev/null

    # When building for real iOS device, we need to open `build_ios/CMakeCache.txt` at this point, search for and FORCIBLY change the value of **HAVE_FFI_CALL** to **1**.
    # For some reason, CMake did not manage to determine that `ffi_call` was available even though it really is the case.
    # Without this, the execution engine is not built with libffi at all.
    sed -i.bak 's/^HAVE_FFI_CALL:INTERNAL=/HAVE_FFI_CALL:INTERNAL=1/g' CMakeCache.txt

    # Build and install
    cmake --build . --target install # >/dev/null 2>/dev/null

    prepare_llvm $targetPlatformArch
}

# Merge the LLVM.a for iphonesimulator & iphonesimulator-arm64 as well as maccatalyst & maccatalyst-arm64 using lipo
# Input: Base platform (iphonesimulator or maccatalyst)
merge_archs() {
    local BASE_PLATFORM=$1
    cd $REPO_ROOT
    if [ -d LLVM-$BASE_PLATFORM ]
    then
        if [ -d LLVM-$BASE_PLATFORM-arm64 ]
        then
            echo "Merge arm64 and x86_64 LLVM.a ($BASE_PLATFORM)"
            cd LLVM-$BASE_PLATFORM
            lipo llvm.a ../LLVM-$BASE_PLATFORM-arm64/llvm.a -output llvm_all_archs.a -create
            test -f llvm_all_archs.a && rm llvm.a && mv llvm_all_archs.a llvm.a
            file llvm.a
        fi
    else
        if [ -d LLVM-$BASE_PLATFORM-arm64 ]
        then
            echo "Rename LLVM-$BASE_PLATFORM-arm64 to LLVM-$BASE_PLATFORM"
            mv LLVM-$BASE_PLATFORM-arm64 LLVM-$BASE_PLATFORM
        fi
    fi
}

create_xcframework() {
    # List of frameworks included in the XCFramework (= AVAILABLE_PLATFORMS without architecture specifications)
    # iphoneos
    local XCFRAMEWORK_PLATFORMS=(iphoneos iphonesimulator) # maccatalyst)

    # List of platforms that need to be merged using lipo due to presence of multiple architectures
    local LIPO_PLATFORMS=(iphonesimulator) # maccatalyst)

    for p in "${LIPO_PLATFORMS[@]}"; do
        merge_archs $p
    done

    local FRAMEWORKS_ARGS=()
    for p in "${XCFRAMEWORK_PLATFORMS[@]}"; do
        FRAMEWORKS_ARGS+=(-library LLVM-$p/llvm.a -headers LLVM-$p/include)

        cd $REPO_ROOT
        test -f libclang.tar.xz || echo "Create clang support headers archive" && tar -cJf libclang.tar.xz LLVM-$p/lib/clang/
    done

    echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
    cd $REPO_ROOT
    xcodebuild -create-xcframework "${FRAMEWORKS_ARGS[@]}" -output LLVM.xcframework
}
