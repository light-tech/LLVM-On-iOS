//
//  LLVMBridge.mm
//  LLVMBridge Implementation, pretty much just forwarding calls to C++
//
//  Created by Lightech on 10/24/2048.
//

#include <cstdlib>
#include <cstdio>

#import "LLVMBridge.h"

// Declaration for clangInterpret method, implemented in Interpreter.cpp
int clangInterpret(int argc, const char **argv);

// Let's hope that this method is exported in the app's binary
extern "C" void testFunction() {
    printf("Hello from iOS app!\n");
}

@implementation LLVMBridge
{
}

- (void)interpretProgram:(nonnull NSData*)fileName
{
    char input_file_path[1024];
    memcpy(input_file_path, fileName.bytes, fileName.length);
    input_file_path[fileName.length] = '\0';

    // Print out the program for inspection.
    printf("\n\n<<<Source Program to Interpret>>>\n<<<%s>>>\n\n", input_file_path);
    auto file = fopen(input_file_path, "rb");
    char c;
    while ((c = fgetc(file)) != EOF)
        printf("%c", c);
    printf("\n\n<<<End of Source Program>>>\n\n");

    const char* argv[2] = { "clang", input_file_path };
    clangInterpret(2, argv);
}

@end
