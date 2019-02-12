/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBControlCore/FBControlCore.h>

NS_ASSUME_NONNULL_BEGIN

@class FBSimulator;

@protocol FBControlCoreLogger;
@protocol FBDataConsumer;

/**
 A command executor for 'simctl'
 */
@interface FBAppleSimctlCommandExecutor : NSObject

#pragma mark Initializers

/**
 Constructs an Executor.

 @param simulator the simulator to execute on
 @return a new command executor
 */
+ (instancetype)executorForSimulator:(FBSimulator *)simulator;

#pragma mark Public Methods

/**
 Constructs a task builder.

 @param command the command name.
 @param arguments the arguments of the command.
 */
- (FBTaskBuilder<NSNull *, id<FBControlCoreLogger>, id<FBControlCoreLogger>> *)taskBuilderWithCommand:(NSString *)command arguments:(NSArray<NSString *> *)arguments;

@end

NS_ASSUME_NONNULL_END
