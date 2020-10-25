LLVM on iOS
===========

Build LLVM for iOS (physical device and simulator)
--------------------------------------------------

From [the official instructions](https://llvm.org/docs/GettingStarted.html):

```shell
    git clone https://github.com/llvm/llvm-project.git # Alternatively, download and extract the monorepo source code from https://releases.llvm.org/download.html
    cd llvm-project
    mkdir build
    cd build
    cmake -G <generator> [options] ../llvm
```

Our script [buildllvm-iOS.sh](buildllvm-iOS.sh) and [buildllvm-iOS-Simulator.sh](buildllvm-iOS-Simulator.sh) build LLVM, Clang and LLD for iOS and iOS simulator respectively. We disable various stuffs such as `terminfo` since there is no terminal in iOS; otherwise, there will be problem when linking in Xcode. Needs:
 * [CMake](https://cmake.org/download/): See [installation instruction](https://tudat.tudelft.nl/installation/setupDevMacOs.html) to add to PATH.
 * [Ninja](https://github.com/ninja-build/ninja/releases): Download and extract the ninja executable to `~/Downloads` folder.

Once the tools are ready, run the script in the `llvm-project` top folder (or `llvm-project-VERSION` if you download the source zipped package instead of cloning).
Once the build process is completed, the library and include headers should be available at `~/Download/LLVM-iOS` or `~/Download/LLVM-iOS-Simulator`.
