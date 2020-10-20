Script to build LLVM projects
=============================

From [the official instructions](https://llvm.org/docs/GettingStarted.html):

    git clone https://github.com/llvm/llvm-project.git
    cd llvm-project
    mkdir build
    cd build
    cmake -G <generator> [options] ../llvm

The script includes command to build for iOS. Needs:
 * [CMake](https://cmake.org/download/)
 * [Ninja](https://github.com/ninja-build/ninja/releases)