//
//  LLVMBridge.mm
//  LLVMBridge Implementation, pretty much just forwarding calls to C++
//
//  Created by Lightech on 10/24/2048.
//

#include <cstdlib>
#include <cstdio>
#include <string>
#include "llvm/Support/raw_ostream.h"

#import "LLVMBridge.h"

// Declaration for clangInterpret method, implemented in Interpreter.cpp
// TODO Might want to extract a header
int clangInterpret(int argc, const char **argv, llvm::raw_ostream &errorOutputStream);

// Let's hope that this method is exported in the app's binary
// Need extern "C" to avoid name mangling so that interpreter can find it
std::string programOutputString;
llvm::raw_string_ostream programOutputStream(programOutputString);
extern "C" void AppConsolePrint(const char *str) {
    programOutputStream << str;
}

// Helper function to construct NSString from a null-terminated C string (presumably UTF-8 encoded)
NSString* NSStringFromCString(const char *text) {
    return [NSString stringWithUTF8String:text];
}

/// Implementation of LLVMInterpreterOutput
@implementation LLVMInterpreterOutput
{
}
@end /* implementation LLVMInterpreterOutput */

/// Implementation of LLVMBridge
@implementation LLVMBridge
{
}

- (nonnull LLVMInterpreterOutput*)interpretProgram:(nonnull NSData*)fileName
{
    // Prepare null terminate string from fileName buffer
    char input_file_path[1024];
    memcpy(input_file_path, fileName.bytes, fileName.length);
    input_file_path[fileName.length] = '\0';

    // Print out the program for inspection.
    printf("\n\n<<<Source Program to Interpret>>>\n<<<%s>>>\n\n", input_file_path);
    auto file = fopen(input_file_path, "rb");
    if (file != NULL) {
        char c;
        while ((c = fgetc(file)) != EOF) printf("%c", c);
        fclose(file);
    }
    printf("\n\n<<<End of Source Program>>>\n\n");

    // Invoke the interpreter
    const char* argv[] = { "clang", input_file_path };
    std::string errorString;
    programOutputString = ""; // reset program output
    llvm::raw_string_ostream errorOutputStream(errorString);
    clangInterpret(2, argv, errorOutputStream);

    // Return compilation and program ouput
    LLVMInterpreterOutput *result = [[LLVMInterpreterOutput alloc] init];
    errorString = errorOutputStream.str(); // Needed to flush the output
    programOutputString = programOutputStream.str();
    printf("\n\nCompilation output: %s\n", errorString.c_str());
    result.compilationOutput = NSStringFromCString(errorString.c_str());
    result.programOutput = NSStringFromCString(programOutputString.c_str());

    return result;
}

@end /* implementation LLVMBridge */
