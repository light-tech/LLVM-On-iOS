LLVM on iOS
===========

The goal of this project is to illustrate how to use LLVM + Clang to provide an iOS app with some scripting capability.

![Edit the program screenshot](Screenshot1.png)
![Interpret the program screenshot](Screenshot2.png)

For the eager reader, we provide a sample iOS app project in the [Sample/](Sample) folder which has **NO license attached** so feel free to do whatever you want with it.
In this app, we use Clang's C interpreter example located in `examples/clang-interpreter/main.cpp` of Clang source code to _interpret a simple C++ program_ and _print out the output on the iOS app's user interface_.
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

4. **For real iOS device**: The implementation of [`llvm::sys::getProcessTriple()`](https://github.com/llvm/llvm-project/blob/master/llvm/lib/Support/Host.cpp) is currently bogus according to the implementation of [`JITTargetMachineBuilder::detectHost()`](https://github.com/llvm/llvm-project/blob/master/llvm/lib/ExecutionEngine/Orc/JITTargetMachineBuilder.cpp).
So we need to add the appropriate conditional compilation directive `#ifdef __aarch64__ ... #else ... #endif` to give it the correct triple.

In the latest version, you should be able to edit the program, interpret it and see the output in the app UI.

### Preparations

Before building the project, you need to either
1. compile LLVM (see instructions down below) and copy the `LLVM.xcframework` to Sample project; or
2. download our prebuilt XCFramework (the file named `LLVM.xcframework.tar.xz`) from our [releases](https://github.com/light-tech/LLVM-On-iOS/releases),
then `cd` to the `Sample` project folder and do
```shell
tar -xzf PATH_TO_DOWNLOADED_TAR_XZ # e.g. ~/Downloads/LLVM.xcframework.tar.xz
```

### Known Limitations

For simulator, can only build **Debug** version only!

You can run the app on the Mac (thank to Mac Catalyst) and iOS simulator. Do NOT expect the app to work on real iPhone due to iOS security preventing [Just-In-Time (JIT) Execution](https://saagarjha.com/blog/2020/02/23/jailed-just-in-time-compilation-on-ios/) that the interpreter example was doing.
By pulling out the device crash logs, the reason turns out to be the fact the [code generated in-memory by LLVM/Clang wasn't signed](http://iphonedevwiki.net/index.php/Code_Signing) and so the app was terminated with SIGTERM CODESIGN.

If there is compilation error, the error message was printed out instead of crashing as expected:

![Add #include non-existing header](Screenshot_Real_iPhone1.png)
![Compilation error was printed out](Screenshot_Real_iPhone2.png)

**Note**: It does work if one [launches the app from Xcode](https://9to5mac.com/2020/11/06/ios-14-2-brings-jit-compilation-support-which-enables-emulation-apps-at-full-performance/) though.

To make the app work on real iPhone _untethered from Xcode_, one possibility is to use compilation into binary, somehow sign it and use [system()](https://stackoverflow.com/questions/32439095/how-to-execute-a-command-line-in-iphone).
Another possibility would be to use the slower LLVM bytecode interpreter instead of ORC JIT that the example was doing, as many [existing terminal apps](https://opensource.com/article/20/9/run-linux-ios) illustrated.

Build LLVM for iOS
------------------

### The tools we needs

 * [Xcode](https://developer.apple.com/xcode/): Download from app store.
 * [CMake](https://cmake.org/download/): See [installation instruction](https://tudat.tudelft.nl/installation/setupDevMacOs.html) to add to `$PATH`.
 * [Ninja](https://github.com/ninja-build/ninja/releases): Download and extract the ninja executable to this repo root.
 * The GNU tools `autoconf`, `automake` and `libtool` are needed to build libffi, install them with homebrew from the terminal
```shell
brew install autoconf automake libtool
```
or [build them from the source](https://gist.github.com/GraemeConradie/49d2f5962fa72952bc6c64ac093db2d5).

### Build libffi

To use the non-JIT interpreter, we want to build LLVM with [libffi](https://github.com/libffi/libffi).

Simply execute [build-libffi.sh](build-libffi.sh) in the repo root.
```shell
./build-libffi.sh iOS      # Build for running on real iPhones
./build-libffi.sh iOS-Sim  # Build for iOS simulator
./build-libffi.sh macOS    # Build for macOS
```

### Build LLVM and co.

Apple has introduced [XCFramework](https://developer.apple.com/videos/play/wwdc2019/416/) to allow packaging a library for multiple-platforms (iOS, Simulator, watchOS, macOS) and CPU architectures (x86_64, arm64) that could be easily added to a project.

Our script [build-llvm-framework.sh](build-llvm-framework.sh) builds LLVM for several iOS platforms and packages it as an XCFramework so we do not have to switch out the libraries when we build the app for different targets (e.g. testing the app on real iPhone arm64 vs simulator x86_64).

At this repo root:
```shell
./build-llvm-framework.sh
```

We can now build the library on an [Azure DevOps](https://lightech.visualstudio.com/LLVM/_build) pipeline.

Behind the Scene
----------------

These days, you probably want to write your app in _Swift_ whereas LLVM library is written in _C++_ so we need to create a _bridge_ to expose LLVM backend to your app Swift frontend. This could be accomplished via Objective-C as an intermediate language:
```
Swift <-> Objective-C <-> C++
```
So to understand how our Sample project works, you need to know
1. how language interoperability works; and
2. how to configure your Xcode project to use it.

### Swift-C++ interoperability

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
 * _Objective-C_ : Simple classes (like [`LLVMBridge`](Sample/Sample/LLVMBridge.h) in our Sample app) to expose service written in C++.
                   The main role is to convert data types between C++ and Swift.
                   For example: Swift's `Data` to Objective-C's `NSData` to C++'s buffer `char*` (and length).
 * _C++_         : Actual implementation of processing functionality.

**Tip**: When writing bridging classes, you should use `NSData` for arguments instead of `NSString` and leave the `String <-> Data` conversion to Swift since you will want a `char*` in C++ anyway.

_Apple_'s [Programming with Objective-C](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Introduction/Introduction.html#//apple_ref/doc/uid/TP40011210)
is fairly useful in helping us write the Objective-C bridging class `LLVMBridge`: Once we pass to C++, we are in our home turf.

### Configure iOS App Xcode Project

1. Create a new iOS app project in Xcode and copy `LLVM.xcframework` to the project folder.

2. In Xcode, add `LLVM.xcframework` to the project's Framework and Libraries. Choose **Do not embed** so that the static library is linked into the app and the entire framework is NOT copied to the app bundle.

3. To create the Objective-C bridge between Swift and C++ mentioned at the beginning, add to your project a new header file, say `LLVMBridge.h` and an implementation file, say `LLVMBridge.mm` (here, we use the `.mm` extension for Objective-C++ since we do need C++ to implement our `LLVMBridge` class) and then change the Objective-C bridging header setting in the project file to tell Xcode that the Objective-C class defined in `LLVMBridge.h` should be exposed to Swift.
Again, go to **Build settings** your project and search for `bridg` and you should find **Objective-C Bridging Header** under **Swift Compiler - General**.
Set it to `PROJECT_NAME/LLVMBridge.h` or if you are using more than just LLVM, a header file of your choice (but that header should include `LLVMBridge.h`).

**Note**: Only Objective-C classes in *Objective-C Bridging Header* are visible to Swift!

![Objective-C Bridging Header Setting](ObjCBridgeHeader.png)

At this point, we should be able to run the project on iOS simulator.
**To build the app for real iOS devices, an extra step is needed.**

4. Since we are using a bunch of precompiled static libraries (and not the actual C++ source code in our app), we need to disable bitcode. Search for `bitcod` and set **Enable Bitcode** setting to `No`.

![Bitcode Setting](DisableBitcode.png)

Now you are ready to make use of LLVM glory.
