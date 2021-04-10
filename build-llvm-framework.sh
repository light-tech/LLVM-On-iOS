# Build LLVM XCFramework
# The script arguments are the platforms to build

PLATFORMS=( "$@" )

# Build various tools such as automake, libtool
export REPO_ROOT=`pwd`
./build-tools.sh
export PATH=$PATH:$REPO_ROOT/tools/bin

# Download and extract ninja
wget https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-mac.zip
unzip ninja-mac.zip

git clone --single-branch --branch release/11.x https://github.com/llvm/llvm-project.git

FRAMEWORKS_ARGS=()
for p in ${PLATFORMS[@]}; do
    echo "Build LLVM for $p"
    ./build-libffi.sh $p
    ./build-llvm.sh $p
    ./prepare-llvm.sh $p
    FRAMEWORKS_ARGS+=("-library" "LLVM-$p/llvm.a" "-headers" "LLVM-$p/include")
    tar -cJf LLVM-$p.tar.xz LLVM-$p/
    tar -cJf LLVM-Clang-$p.tar.xz LLVM-$p/lib/clang/
done

echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output LLVM.xcframework
tar -cJf LLVM.xcframework.tar.xz LLVM.xcframework
