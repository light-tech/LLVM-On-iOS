# Needs autoconf, automake and libtool; assumed installed and added to $PATH
# Install with homebrew or from source directly
# TODO Maybe check if the commands are present and build the ones we need? Homebrew is fairly big and time-consuming to install.

REPO_DIR=`pwd`
LIBFFI_DIR=$REPO_DIR/libffi

git clone https://github.com/libffi/libffi.git

cd libffi

# xcodebuild -list
# Note that we need to run xcodebuild twice: the first run generates necessary headers whereas the second run actually compiles the library
for r in {1..2}; do
    xcodebuild -scheme libffi-iOS -configuration Release SYMROOT="$LIBFFI_DIR"
done
