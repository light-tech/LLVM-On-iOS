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
 * [Xcode](https://developer.apple.com/xcode/): Download from app store.
 * [CMake](https://cmake.org/download/): See [installation instruction](https://tudat.tudelft.nl/installation/setupDevMacOs.html) to add to PATH.
 * [Ninja](https://github.com/ninja-build/ninja/releases): Download and extract the ninja executable to `~/Downloads` folder.

Once the tools are ready, run the script in the `llvm-project` top folder (or `llvm-project-VERSION` if you download the source zipped package instead of cloning).
Once the build process is completed, the library and include headers should be available at `~/Download/LLVM-iOS` or `~/Download/LLVM-iOS-Simulator`.

Before being able to use in Xcode, in the built folder, we first need to move the `lib/clang/` and `lib/cmake` and `lib/*.dylib` out of `lib/`:
```shell
cd ~/Download/LLVM-iOS
mkdir lib2
mv lib/clang lib2/
mv lib/cmake lib2/
mv lib/*.dylib lib2/
```
Otherwise, iOS will crash when loading dynamic libraries.
Maybe remove the unnecessary stuffs in `bin` as well.
Running our script [prepare-llvm.sh](prepare-llvm.sh) in the LLVM installation folder i.e. `~/Download/LLVM-iOS` or `~/Download/LLVM-iOS-Simulator` will perform the necessary set-up.

Our Sample iOS Project
----------------------

We provide a sample iOS app project in the [Sample/](Sample) folder; no license attached so feel free to do whatever you want with it.
In this project, we use Clang's C interpreter example located in `examples/clang-interpreter/main.cpp` of Clang source code to interpret a simple C++ program.
(The file was renamed to `Interpreter.cpp` to fit in with iOS development style.)
The code is pretty much copied verbatim except for some minor modifications, namely:

1. We change the `main` function name to `clangInterpret` since iOS app already has `main` function.

2. We comment out the last line
```c++
// llvm::llvm_shutdown();
```
so that you can call `clangInterpret` again in the app. Originally, the example was a one-shot command line program where this makes sense.

3. We add a third parameter
```c++
llvm::raw_ostream &errorOutputStream
```
to `clangInterpret` and replace all `llvm::errs()` with `errorOutputStream` so we can capture the compilation output and pass it back to the app front-end to display to users.

In the latest version, you should be able to edit the program, interpret it and see the output.
Before building the project, you need to copy the LLVM installation folder, say `~/Download/LLVM-iOS-Simulator`, to the root folder of the project like this
```shell
cp ~/Download/LLVM-iOS-Simulator LLVM  # Assuming at Sample project folder
```
Here, we copy the `LLVM-iOS-Simulator` to build the app and run it on the simulator.

![Edit the program screenshot](Screenshot1.png)
![Interpret the program screenshot](Screenshot2.png)

Read on for details on how to create and configure your own project.

**Known Limitation**: For simulator, can only build **Debug** version only! The current app does not work on real device yet!

Behind the Scene: Configure iOS App Xcode Project
-------------------------------------------------

These days, you probably want to write your app in _Swift_ whereas LLVM library is written in _C++_ so we need to create a _bridge_ to expose LLVM backend to your app Swift frontend. This could be accomplished via Objective-C as an intermediate language:
```
Swift <-> Objective-C <-> C++
```
A typical approach will be using
 * Swift: anything iOS-related (UI, file system, Internet, ...)
 * Objective-C: simple class say `LLVMBridge` to expose service such as compilation; basically to convert data types between C++ and Swift such as Swift's `Data` to Objective-C's `NSData` to C++'s buffer `char*`.
 * C++: actual implementation of processing functionality.

Go to [Further Readings](#further-readings) for more details.

1. Create a new iOS app project in Xcode and copy an LLVM installation to the project folder.
Unfortunately, LLVM cannot build fat binary for iOS at the moment so we have to manually switch between the two LLVM installations when we switch testing between real iOS device (ARM) or iOS simulator (x86_64).
A good approach is to copy both folders `~/Download/LLVM-iOS` or `~/Download/LLVM-iOS-Simulator` to the project folder and rename one of them to `LLVM` depending on our build target.

2. Add the LLVM static libraries to your project by right click on the Sample project, choose **Add files to "YOUR PROJECT NAME"** and select the **LLVM/lib** folder.
Enable **Create groups** but not **Copy items if needed**.

3. Next, we add `LLVM/include` to header search path so that our C++/Objective-C++ code can `#include` the LLVM's headers.
Go to **Build settings** your project, click on **All** and search for `header`.
You should find **Header Search Paths** under **Search Paths**.
Add a new item `$(PROJECT_DIR)/LLVM/include`.

![Header Search Paths Setting](HeaderSearchPaths.png)

4. To create the Objective-C bridge between Swift and C++ mentioned at the beginning, add to your project a new header file, say `LLVMBridge.h` and an implementation file, say `LLVMBridge.mm` (here, we use the `.mm` extension for Objective-C++ since we do need C++ to implement our `LLVMBridge` class) and then change the Objective-C bridging header setting in the project file to tell Xcode that the Objective-C class defined in `LLVMBridge.h` should be exposed to Swift.
Again, go to **Build settings** your project and search for `bridg` and you should find **Objective-C Bridging Header** under **Swift Compiler - General**.
Set it to `PROJECT_NAME/LLVMBridge.h` or if you are using more than just LLVM, a header file of your choice (but that header should include `LLVMBridge.h`).

![Objective-C Bridging Header Setting](ObjCBridgeHeader.png)

At this point, we should be able to run the project on iOS simulator.
**To build the app on real iOS device, an extra step is needed.**

5. Since we are using a bunch of precompiled static libraries (and not the actual C++ source code in our app), we need to disable bitcode. Search for `bitcod` and set **Enable Bitcode** setting to `No`.

![Bitcode Setting](DisableBitcode.png)

Now you are ready to make use of LLVM glory.

Further Readings
----------------

You might want to start with _Anthony Nguyen_'s 
[Using C++ in Objective-C iOS app: My first walk](https://medium.com/@nguyenminhphuc/using-c-in-objective-c-ios-app-my-first-walk-77319d94a940)
for a quick intro on how to make use of C++ in Objective-C.
(Note that both C++ and Objective-C are extensions of C and reduces to C.)
An easy read on Objective-C and Swift interoperability could be found in
[Understanding Objective-C and Swift interoperability](https://rderik.com/blog/understanding-objective-c-and-swift-interoperability/#expose-swift-code-to-objective-c)
by _RDerik_.
Combining these two articles is the basis for our Sample app.

_Apple_'s [Programming with Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011210)
is fairly useful in helping us write the Objective-C bridging class `LLVMBridge`: Once we pass to C++, we are in our home turf.
