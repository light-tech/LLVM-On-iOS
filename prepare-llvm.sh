# Script to prepare the LLVM built for usage in Xcode
# To be executed in LLVM-iOS or LLVM-iOS-Simulator folder

# Make a text file with the name of the folder where this script was run so that we can distinguish between them in app project dir 
folder=$(basename $(pwd))
touch $folder.txt

# Remove unnecessary executables and support files
rm -rf bin libexec share

# Move unused stuffs in lib to a temporary lib2 (restored when necessary)
mkdir lib2
mv lib/clang lib2/
mv lib/cmake lib2/
mv lib/*.dylib lib2/
mv lib/libc++* lib2/

# Copy libffi

DOWNLOADS=~/Downloads
if [ $folder = "LLVM-iOS" ]; then
    LIBFFI_BUILD_DIR=$DOWNLOADS/libffi/Release-iphoneos
else
    LIBFFI_BUILD_DIR=$DOWNLOADS/libffi/Release-iphonesimulator
fi

cp -r $LIBFFI_BUILD_DIR/include/ffi ./include/
cp $LIBFFI_BUILD_DIR/libffi.a ./lib/