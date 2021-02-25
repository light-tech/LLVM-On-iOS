# Script to prepare the LLVM built for usage in Xcode

PLATFORM=$1

case $PLATFORM in
  "iOS")
	echo "Prepare LLVM for iOS device"
    ARCH=arm64
    LIBFFI_BUILD_DIR=`pwd`/libffi/Release-iphoneos;;
  "iOS-Sim")
    echo "Prepare LLVM for iOS simulator"
    LIBFFI_BUILD_DIR=`pwd`/libffi/Release-iphonesimulator;;
  "macOS")
    echo "Prepare LLVM for MacOS"
    LIBFFI_BUILD_DIR=`pwd`/libffi/Release-maccatalyst;;
  *)
    echo "Unknown or missing platform!"
	exit 1;;
esac

cd LLVM-$PLATFORM

# Make a text file with the name of the folder where this script was run so that we can distinguish between them in app project dir 
folder=$(basename $(pwd))
touch $folder.txt

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
