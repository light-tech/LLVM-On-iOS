# Script to prepare the LLVM built for usage in Xcode

PLATFORM=$1
LIBFFI_BUILD_DIR=`pwd`/libffi/Release-$PLATFORM

cd LLVM-$PLATFORM

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
