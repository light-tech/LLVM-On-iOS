//
//  ContentView.swift
//  Sample
//
//  Created by Lightech on 10/24/2048.
//

import SwiftUI

// Path to the app's ApplicationSupport directory where we will put a.k.a. hide our source code
let applicationSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)

// Global instance of LLVMBridge
let llvm: LLVMBridge = LLVMBridge()

struct ContentView: View {

    @State var output: String = "Clang output goes here!"

    var body: some View {
        VStack {
            Button("Interpret Sample Program", action: interpretSampleProgram)
            Text(output)
        }
    }

    func interpretSampleProgram() {
        // Prepare a sample C++ source code file hello.cpp
        let filePath = applicationSupportPath[0] + "hello.cpp"
        let fileContent = """
extern "C" void printf(const char* fmt, ...);
extern "C" void testFunction();
int main() {
    testFunction();
    printf("Hello world!");
    return 0;
}
"""
        FileManager.default.createFile(atPath: filePath,
                                       contents: fileContent.data(using: .utf8)!,
                                       attributes: nil)

        // Compile and interpret the program
        print("Interpret sample program at ", filePath)
        llvm.interpretProgram(filePath.data(using: .utf8)!)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
