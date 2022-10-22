REPO_ROOT=`pwd`

# Merge the LLVM.a for iphonesimulator & iphonesimulator-arm64 as well as maccatalyst & maccatalyst-arm64 using lipo
# Input: Base platform (iphonesimulator or maccatalyst)
function merge_archs() {
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


# List of frameworks included in the XCFramework (= AVAILABLE_PLATFORMS without architecture specifications)
# iphoneos
XCFRAMEWORK_PLATFORMS=(iphoneos iphonesimulator) # maccatalyst)

# List of platforms that need to be merged using lipo due to presence of multiple architectures
LIPO_PLATFORMS=(iphonesimulator) # maccatalyst)

for p in "${LIPO_PLATFORMS[@]}"; do
    merge_archs $p
done

FRAMEWORKS_ARGS=()
for p in "${XCFRAMEWORK_PLATFORMS[@]}"; do
    FRAMEWORKS_ARGS+=(-library LLVM-$p/llvm.a -headers LLVM-$p/include)

    cd $REPO_ROOT
    test -f libclang.tar.xz || echo "Create clang support headers archive" && tar -cJf libclang.tar.xz LLVM-$p/lib/clang/
done

echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
cd $REPO_ROOT
xcodebuild -create-xcframework "${FRAMEWORKS_ARGS[@]}" -output LLVM.xcframework
