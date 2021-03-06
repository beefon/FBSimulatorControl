/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorLoggingEventSink.h"

#import <FBControlCore/FBControlCore.h>

#import "FBSimulator.h"
#import "FBSimulatorAgentOperation.h"
#import "FBSimulatorApplicationOperation.h"

NSString *BoolDescription(BOOL b);
NSString *BoolDescription(BOOL b)
{
  return b ? @"YES" : @"NO";
}

@interface FBSimulatorLoggingEventSink ()

@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;

@end

@implementation FBSimulatorLoggingEventSink

#pragma mark Initializers

+ (instancetype)withSimulator:(FBSimulator *)simulator logger:(id<FBControlCoreLogger>)logger
{
  return [[self alloc] initWithLogger:logger];
}

- (instancetype)initWithLogger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _logger = logger;

  return self;
}

#pragma mark FBSimulatorEventSink Implementation

- (void)containerApplicationDidLaunch:(FBProcessInfo *)applicationProcess
{
  [self.logger logFormat:@"Container Application Did Launch => %@", applicationProcess.shortDescription];
}

- (void)containerApplicationDidTerminate:(FBProcessInfo *)applicationProcess expected:(BOOL)expected
{
  [self.logger logFormat:@"Container Application Did Terminate => %@, Expected = %@", applicationProcess.shortDescription, BoolDescription(expected)];
}

- (void)connectionDidConnect:(FBSimulatorConnection *)connection
{
  [self.logger logFormat:@"Connection Did Connect => %@", connection];
}

- (void)connectionDidDisconnect:(FBSimulatorConnection *)connection expected:(BOOL)expected
{
  [self.logger logFormat:@"Connection Did Disconnect => %@, Expected %@", connection, BoolDescription(expected)];
}

- (void)simulatorDidLaunch:(FBProcessInfo *)launchdProcess
{
  [self.logger logFormat:@"Simulator Did launch => %@", launchdProcess.shortDescription];
}

- (void)simulatorDidTerminate:(FBProcessInfo *)launchdProcess expected:(BOOL)expected
{
  [self.logger logFormat:@"Simulator Did Terminate => %@ Expected = %@", launchdProcess.shortDescription, BoolDescription(expected)];
}

- (void)agentDidLaunch:(FBSimulatorAgentOperation *)operation
{
  [self.logger logFormat:@"Agent Did Launch => %@", operation];
}

- (void)agentDidTerminate:(FBSimulatorAgentOperation *)operation statLoc:(int)statLoc
{
  [self.logger logFormat:@"Agent Did Terminate => Value %d %@", statLoc, operation];
}

- (void)applicationDidLaunch:(FBSimulatorApplicationOperation *)operation
{
  [self.logger logFormat:@"Application Did Launch => %@", operation];
}

- (void)applicationDidTerminate:(FBSimulatorApplicationOperation *)operation expected:(BOOL)expected
{
  [self.logger logFormat:@"Application Did Terminate => Expected %@ %@", BoolDescription(expected), operation];
}

- (void)didChangeState:(FBiOSTargetState)state
{
  [self.logger logFormat:@"Did Change State => %@", FBiOSTargetStateStringFromState(state)];
}

@end
