# Build LLVM XCFramework

wget https://github.com/light-tech/LLVM-On-iOS/releases/download/libffi_v3.3plus/libffi.tar.xz

tar xzf libffi.tar.xz

test -d libffi && echo "libffi was successfully extracted"

git clone --single-branch --branch release/11.x https://github.com/llvm/llvm-project.git

PLATFORMS=("iOS" "macOS") # iOS-Sim
for p in ${PLATFORMS[@]}; do
    echo "Build LLVM for $p"
    ./build-llvm.sh $p
    ./prepare-llvm.sh $p
    tar -cJf LLVM-$p.tar.xz LLVM-$p/
    tar -cJf LLVM-Clang-$p.tar.xz LLVM-$p/lib/clang/
done

xcodebuild -create-xcframework -library LLVM-iOS/llvm.a -headers LLVM-iOS/include -library LLVM-macOS/llvm.a -headers LLVM-macOS/include -output LLVM.xcframework
