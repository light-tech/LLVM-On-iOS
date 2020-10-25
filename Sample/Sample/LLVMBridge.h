//
//  LLVMBridge.h
//  Declaration of Objective-C class LLVMBridge to expose C++ services of LLVM to Swift
//  For simplicity, this file is also used as Swift-ObjC bridging header in this sample project
//
//  Created by Lightech on 10/24/2048.
//

#ifndef LLVMBridge_h
#define LLVMBridge_h

#import <Foundation/Foundation.h>

@interface LLVMBridge : NSObject

- (void)interpretProgram:(nonnull NSData*)fileName;

@end

#endif /* LLVMBridge_h */
