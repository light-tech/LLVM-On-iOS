//
//  ContentView.swift
//  Sample
//
//  Created by Lightech on 10/24/2048.
//

import SwiftUI

// Path to the app's ApplicationSupport directory where we will put a.k.a. hide our source code
let applicationSupportURL = try! FileManager.default.url(for: .applicationSupportDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: true)

// Global instance of LLVMBridge
let llvm: LLVMBridge = LLVMBridge()

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

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

    var body: some View {
        if (sizeClass == .compact) {
            TabView {
                VStack {
                    Button("Interpret Sample Program", action: interpretSampleProgram)
                    TextEditor(text: $program)
                }.tabItem {
                    Image(systemName: "doc.plaintext")
                    Text("Source code")
                }

                VStack {
                    Text(compilationOutput)
                    Divider()
                    Text(programOutput)
                }.tabItem {
                    Image(systemName: "greaterthan.square")
                    Text("Output")
                }
            }
        } else {
            VStack {
                Button("Interpret Sample Program", action: interpretSampleProgram)
                    .padding()
                HStack {
                    TextEditor(text: $program)
                    Divider()
                    VStack {
                        Text(compilationOutput)
                        Divider()
                        Text(programOutput)
                    }
                }
            }
        }
    }

    func interpretSampleProgram() {
        // Prepare a sample C++ source code file hello.cpp
        let filePath = applicationSupportURL.appendingPathComponent("hello.cpp")

        FileManager.default.createFile(atPath: filePath.path,
                                       contents: program.data(using: .utf8)!,
                                       attributes: nil)

        // Compile and interpret the program
        print("Interpret sample program at ", filePath)
        let output = llvm.interpretProgram(filePath.path.data(using: .utf8)!)
        compilationOutput = output.compilationOutput!
        programOutput = output.programOutput!
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
