/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <XCTestBootstrap/XCTestBootstrap.h>
#import <FBSimulatorControl/FBSimulatorControlConfiguration.h>

@protocol FBXCTestSimulatorConfigurator;
@protocol FBControlCoreLogger;

NS_ASSUME_NONNULL_BEGIN

/**
 Represents the Command Line for fbxctest.
 */
@interface FBXCTestCommandLine : NSObject

/**
 Creates and loads a configuration from arguments.

 @param arguments the Arguments to the fbxctest process
 @param environment environment additions for the process under test.
 @param simulatorSetPath simulator set path.
 @Param timeout the timeout of the test.
 @param error an error out for any error that occurs
 @return a new test run configuration.
 */
+ (nullable instancetype)commandLineFromArguments:(NSArray<NSString *> *)arguments
                      processUnderTestEnvironment:(NSDictionary<NSString *, NSString *> *)environment
                                 simulatorSetPath:(NSString *)simulatorSetPath
                                 workingDirectory:(NSString *)workingDirectory
                                          timeout:(NSTimeInterval)timeout
                                           logger:(nullable id<FBControlCoreLogger>)logger
                                            error:(NSError **)error;

/**
 The Designated Inititalizer

 @param configuration the configuration for the test run.
 @param destination the destination to run against.
 */
+ (instancetype)commandLineWithConfiguration:(FBXCTestConfiguration *)configuration
                                 destination:(FBXCTestDestination *)destination
                      simulatorConfigurators:(NSArray<id<FBXCTestSimulatorConfigurator>> *)simulatorConfigurators
                  simulatorManagementOptions:(FBSimulatorManagementOptions)simulatorManagementOptions;

#pragma mark Properties

/**
 The Test Configuration
 */
@property (nonatomic, strong, readonly) FBXCTestConfiguration *configuration;

/**
 The Destination
 */
@property (nonatomic, strong, readonly) FBXCTestDestination *destination;

#pragma mark Timeouts

/**
 The Timeout for getting the test into an executable state.
 For example, preparing a Simulator.
 */
@property (nonatomic, assign, readonly) NSTimeInterval testPreparationTimeout;

/**
 The Timeout to perform all operations.
 */
@property (nonatomic, assign, readonly) NSTimeInterval globalTimeout;

#pragma mark Simulator Configuration

@property (nonatomic, copy, readonly) NSArray<id<FBXCTestSimulatorConfigurator>> *simulatorConfigurators;

@property (nonatomic, assign, readonly) FBSimulatorManagementOptions simulatorManagementOptions;

@end

NS_ASSUME_NONNULL_END
