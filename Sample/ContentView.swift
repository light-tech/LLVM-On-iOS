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

    @State var program: String = """
extern "C" void printf(const char* fmt, ...);

extern "C" void AppConsolePrint(const char *str);

int main() {
    printf("Hello world!");
    AppConsolePrint("Hello world!");
    return 0;
}
"""

    @State var compilationOutput: String = ""
    @State var programOutput: String = ""
    @State var selectedView = 0

    var body: some View {
        TabView(selection: $selectedView) {
            VStack {
                Button("Interpret Sample Program", action: interpretSampleProgram)
                TextEditor(text: $program)
            }.tabItem {
                    Image(systemName: "doc.plaintext")
                    Text("Source code")
                }.tag(0)
            VStack {
                Text(compilationOutput)
                Text(programOutput)
            }.tabItem {
                    Image(systemName: "greaterthan.square")
                    Text("Output")
                }.tag(1)
        }
    }

    func interpretSampleProgram() {
        // Prepare a sample C++ source code file hello.cpp
        let filePath = applicationSupportPath[0] + "/hello.cpp"

        FileManager.default.createFile(atPath: filePath,
                                       contents: program.data(using: .utf8)!,
                                       attributes: nil)

        // Compile and interpret the program
        print("Interpret sample program at ", filePath)
        let output = llvm.interpretProgram(filePath.data(using: .utf8)!)
        compilationOutput = output.compilationOutput!
        programOutput = output.programOutput!
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
