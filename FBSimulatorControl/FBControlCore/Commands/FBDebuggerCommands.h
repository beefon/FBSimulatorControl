/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBControlCore/FBFuture.h>
#import <FBControlCore/FBiOSTargetCommandForwarder.h>
#import <FBControlCore/FBiOSTargetFuture.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A protocol for a running debug server.
 */
@protocol FBDebugServer <FBiOSTargetContinuation>

/**
 The commands to execute within lldb to start a debug server.
 */
@property (nonatomic, copy, readonly) NSArray<NSString *> *lldbBootstrapCommands;

@end

/**
 Commands for starting a debug server.
 */
@protocol FBDebuggerCommands <NSObject, FBiOSTargetCommand>

/**
 Starts a gdb debug server for a given bundle id.
 The server is then bound on the TCP port provided.

 @param path the path of the application to debug.
 @param port the TCP port to bind on the debug server on.
 @return a future that resolves with a debug server.
 */
- (FBFuture<id<FBDebugServer>> *)launchDebugServerForApplicationWithPath:(NSString *)path port:(in_port_t)port;

@end

NS_ASSUME_NONNULL_END
