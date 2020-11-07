LLVM on iOS
===========

Build LLVM for iOS (physical device and simulator)
--------------------------------------------------

From [the official instructions](https://llvm.org/docs/GettingStarted.html):

```shell
# Alternative to git clone is to download and extract the monorepo source code from https://releases.llvm.org/download.html
git clone https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build
cd build
cmake -G <generator> [options] ../llvm
```

Our script [buildllvm-iOS.sh](buildllvm-iOS.sh) and [buildllvm-iOS-Simulator.sh](buildllvm-iOS-Simulator.sh) build LLVM, Clang, LLD and LibC++ for iOS and iOS simulator respectively.
We disable various stuffs such as `terminfo` since there is no terminal in iOS; otherwise, there will be problem when linking in Xcode.
Needs:
 * [Xcode](https://developer.apple.com/xcode/): Download from app store.
 * [CMake](https://cmake.org/download/): See [installation instruction](https://tudat.tudelft.nl/installation/setupDevMacOs.html) to add to PATH.
 * [Ninja](https://github.com/ninja-build/ninja/releases): Download and extract the ninja executable to `~/Downloads` folder.

Once the tools are ready, run the script in the `llvm-project` top folder (or `llvm-project-VERSION` if you download the source zipped package instead of cloning).

Once the build process is completed, the library and include headers should be installed at `~/Download/LLVM-iOS` or `~/Download/LLVM-iOS-Simulator`.
(We will subsequently refer to these directories as the _LLVM installation dir_.)

Before being able to use in Xcode, in the built folder, we first need to move the `lib/clang/` and `lib/cmake` and `lib/*.dylib` out of `lib/`:
```shell
cd ~/Download/LLVM-iOS
mkdir lib2
mv lib/clang lib2/
mv lib/cmake lib2/
mv lib/*.dylib lib2/
```
Otherwise, iOS will crash when loading dynamic libraries.
Running our script [prepare-llvm.sh](prepare-llvm.sh) in the LLVM installation dir will perform the necessary set-up.

Optionally, you could move the `liblld*` to `lib2` as well and the `bin` since it's unlikely you need binary linkage and the `clang` command line program in iOS app.

Our Sample iOS Project
----------------------

We provide a sample iOS app project in the [Sample/](Sample) folder; _no license attached_ so feel free to do whatever you want with it.
In this project, we use Clang's C interpreter example located in `examples/clang-interpreter/main.cpp` of Clang source code to interpret a simple C++ program.
(The file was renamed to `Interpreter.cpp` to fit in with iOS development style.)
The code is pretty much copied verbatim except for some minor modifications, namely:

1. We change the `main` function name to `clangInterpret` since iOS app already has `main` function.

2. We comment out the last line
```c++
// llvm::llvm_shutdown();
```
so that you can _call `clangInterpret` again_ in the app.
This line only makes sense in the original program because it was a one-shot command line program.

3. We add a third parameter
```c++
llvm::raw_ostream &errorOutputStream
```
to `clangInterpret` and replace all `llvm::errs()` with `errorOutputStream` so we can capture the compilation output and pass it back to the app front-end to display to the user.

4. **For real iOS device**: The implementation of [`llvm::sys::getProcessTriple()`](https://github.com/llvm/llvm-project/blob/master/llvm/lib/Support/Host.cpp) is currently bogus according to the implementation of [`JITTargetMachineBuilder::detectHost()`](https://github.com/llvm/llvm-project/blob/master/llvm/lib/ExecutionEngine/Orc/JITTargetMachineBuilder.cpp): _FIXME: getProcessTriple is bogus. It returns the host LLVM was compiled on, rather than a valid triple for the current process._
So we need to add the appropriate conditional compilation directive `#if TARGET_OS_SIMULATOR ... #else ... #endif` to give it the correct triple. (The platform macro is documented at `<TargetConditionals.h>`.)

In the latest version, you should be able to edit the program, interpret it and see the output in the app UI.

Before building the project, you need to copy the LLVM installation folder, say `~/Download/LLVM-iOS-Simulator`, to the root folder of the project like this
```shell
# At Sample project folder:
cp ~/Download/LLVM-iOS-Simulator LLVM
```
Here, we copy the `LLVM-iOS-Simulator` to build the app and run it on the simulator.

![Edit the program screenshot](Screenshot1.png)
![Interpret the program screenshot](Screenshot2.png)

Read on for details on how to create and configure your own project.

### Known Limitation
For simulator, can only build **Debug** version only!
Do NOT expect the app to work on real iPhone due to iOS security preventing [Just-In-Time (JIT) Execution](https://saagarjha.com/blog/2020/02/23/jailed-just-in-time-compilation-on-ios/) that the interpreter example was doing.
By pulling out the device crash logs, the reason turns out to be the fact the [code generated in-memory by LLVM/Clang wasn't signed](http://iphonedevwiki.net/index.php/Code_Signing) and so the app was terminated with SIGTERM CODESIGN.
(It does work sometimes if one [launches the app from Xcode](https://9to5mac.com/2020/11/06/ios-14-2-brings-jit-compilation-support-which-enables-emulation-apps-at-full-performance/) though.)
If there is compilation error, the error message was printed out instead of crashing as expected:

![Add #include non-existing header](Screenshot_Real_iPhone1.png)
![Compilation error was printed out](Screenshot_Real_iPhone2.png)

To make the app work on real iPhone, compilation into binary, somehow sign it and use [system()](https://stackoverflow.com/questions/32439095/how-to-execute-a-command-line-in-iphone) is a possibility.
Another possibility would be to use the slower LLVM bytecode interpreter instead of ORC JIT that the example was doing, as many [existing terminal apps](https://opensource.com/article/20/9/run-linux-ios) illustrated.

Behind the Scene: Configure iOS App Xcode Project
-------------------------------------------------

These days, you probably want to write your app in _Swift_ whereas LLVM library is written in _C++_ so we need to create a _bridge_ to expose LLVM backend to your app Swift frontend. This could be accomplished via Objective-C as an intermediate language:
```
Swift <-> Objective-C <-> C++
```
Go to [Further Readings](#further-readings) for more details on Swift-C++ interoperability.

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

**Note**: Only Objective-C classes in *Objective-C Bridging Header* are visible to Swift!

![Objective-C Bridging Header Setting](ObjCBridgeHeader.png)

At this point, we should be able to run the project on iOS simulator.
**To build the app for real iOS devices, an extra step is needed.**

5. Since we are using a bunch of precompiled static libraries (and not the actual C++ source code in our app), we need to disable bitcode. Search for `bitcod` and set **Enable Bitcode** setting to `No`.

![Bitcode Setting](DisableBitcode.png)

Now you are ready to make use of LLVM glory.

Further Readings
----------------

To start, you might want to start with _Anthony Nguyen_'s 
[Using C++ in Objective-C iOS app: My first walk](https://medium.com/@nguyenminhphuc/using-c-in-objective-c-ios-app-my-first-walk-77319d94a940)
for a quick intro on how to make use of C++ in Objective-C.
(Note that both C++ and Objective-C are extensions of C and reduces to C.)
An easy read on Objective-C and Swift interoperability could be found in
[Understanding Objective-C and Swift interoperability](https://rderik.com/blog/understanding-objective-c-and-swift-interoperability/#expose-swift-code-to-objective-c)
by _RDerik_.
Combining these two articles is the basis for our Sample app.

A typical approach to allow C++ in Swift-based iOS app will be using
 * _Swift_       : Anything iOS-related (UI, file system access, Internet, ...)
 * _Objective-C_ : Simple classes (like `LLVMBridge` in our Sample app) to expose service written in C++.
                   The main role is to convert data types between C++ and Swift.
                   For example: Swift's `Data` to Objective-C's `NSData` to C++'s buffer `char*` (and length).
 * _C++_         : Actual implementation of processing functionality.

**Tip**: When writing bridging classes, you should use `NSData` for arguments instead of `NSString` and leave the `String <-> Data` conversion to Swift since you will want a `char*` in C++ anyway.

_Apple_'s [Programming with Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011210)
is fairly useful in helping us write the Objective-C bridging class `LLVMBridge`: Once we pass to C++, we are in our home turf.
