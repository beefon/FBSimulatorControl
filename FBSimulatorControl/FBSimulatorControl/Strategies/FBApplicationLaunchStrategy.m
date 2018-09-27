/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBApplicationLaunchStrategy.h"

#import <FBControlCore/FBControlCore.h>

#import <CoreSimulator/SimDevice.h>

#import "FBApplicationLaunchStrategy.h"
#import "FBSimulatorApplicationOperation.h"
#import "FBSimulator+Private.h"
#import "FBSimulator.h"
#import "FBSimulatorBridge.h"
#import "FBSimulatorConnection.h"
#import "FBSimulatorDiagnostics.h"
#import "FBSimulatorError.h"
#import "FBSimulatorEventSink.h"
#import "FBSimulatorDiagnostics.h"
#import "FBSimulatorProcessFetcher.h"
#import "FBSimulatorSubprocessTerminationStrategy.h"
#import "FBProcessLaunchConfiguration+Simulator.h"
#import "FBSimulatorLaunchCtlCommands.h"

@interface FBApplicationLaunchStrategy ()

@property (nonnull, nonatomic, strong, readonly) FBSimulator *simulator;

@end

@interface FBApplicationLaunchStrategy_Bridge : FBApplicationLaunchStrategy

@end

@interface FBApplicationLaunchStrategy_CoreSimulator : FBApplicationLaunchStrategy

@end

@implementation FBApplicationLaunchStrategy

#pragma mark Initializers

+ (instancetype)strategyWithSimulator:(FBSimulator *)simulator useBridge:(BOOL)useBridge;
{
  Class strategyClass = useBridge ? FBApplicationLaunchStrategy_CoreSimulator.class : FBApplicationLaunchStrategy_CoreSimulator.class;
  return [[strategyClass alloc] initWithSimulator:simulator];
}

+ (instancetype)strategyWithSimulator:(FBSimulator *)simulator
{
  return [self strategyWithSimulator:simulator useBridge:NO];
}

- (instancetype)initWithSimulator:(FBSimulator *)simulator
{
  self = [super init];
  if (!self){
    return nil;
  }

  _simulator = simulator;

  return self;
}

#pragma mark Public

- (FBFuture<FBSimulatorApplicationOperation *> *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch
{
  FBSimulator *simulator = self.simulator;
  return [[[[[[simulator
    installedApplicationWithBundleID:appLaunch.bundleID]
    rephraseFailure:@"App %@ can't be launched as it isn't installed", appLaunch.bundleID]
    onQueue:simulator.workQueue fmap:^(id _) {
      return [self confirmApplicationIsNotRunning:appLaunch.bundleID];
    }]
    onQueue:simulator.workQueue fmap:^(id _) {
      return [appLaunch createOutputForSimulator:simulator];
    }]
    onQueue:simulator.workQueue fmap:^(NSArray<FBProcessOutput *> *outputs) {
      return [FBFuture futureWithFutures:@[
          [outputs[0] providedThroughFile],
          [outputs[1] providedThroughFile],
      ]];
    }]
    onQueue:simulator.workQueue fmap:^ FBFuture<FBSimulatorApplicationOperation *> * (NSArray<id<FBProcessFileOutput>> *outputs) {
      id<FBProcessFileOutput> stdOut = outputs[0];
      id<FBProcessFileOutput> stdErr = outputs[1];

      FBFuture<NSNumber *> *launch = [self launchApplication:appLaunch stdOut:stdOut stdErr:stdErr];
      return [FBSimulatorApplicationOperation operationWithSimulator:simulator configuration:appLaunch stdOut:stdOut stdErr:stdErr launchFuture:launch];
    }];
}

- (FBFuture<FBSimulatorApplicationOperation *> *)launchOrRelaunchApplication:(FBApplicationLaunchConfiguration *)appLaunch
{
  NSParameterAssert(appLaunch);

  // Kill the Application if it exists. Don't bother killing the process if it doesn't exist
  FBSimulator *simulator = self.simulator;
  return [[[simulator
    runningApplicationWithBundleID:appLaunch.bundleID]
    onQueue:self.simulator.workQueue chain:^FBFuture<NSNull *> *(FBFuture<FBProcessInfo *> *future) {
      FBProcessInfo *process = future.result;
      if (process) {
        return [[FBSimulatorSubprocessTerminationStrategy strategyWithSimulator:simulator] terminate:process];
      }
      return [FBFuture futureWithResult:NSNull.null];
    }]
    onQueue:simulator.workQueue fmap:^FBFuture *(NSNull *result) {
      return [simulator launchApplication:appLaunch];
    }];
}

#pragma mark Private

- (FBFuture<NSNumber *> *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOut:(id<FBProcessFileOutput>)stdOut stdErr:(id<FBProcessFileOutput>)stdErr
{
  // Start reading now, but don't block on the resolution, we will ensure that the read has started after the app has launched.
  FBFuture *readingFutures = [FBFuture futureWithFutures:@[
    [stdOut startReading],
    [stdErr startReading],
  ]];

  return [[self
    launchApplication:appLaunch stdOutPath:stdOut.filePath stdErrPath:stdErr.filePath]
    onQueue:self.simulator.workQueue fmap:^(NSNumber *result) {
      return [readingFutures mapReplace:result];
    }];
}

- (FBFuture<NSNumber *> *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return 0;
}

- (FBFuture<NSNull *> *)confirmApplicationIsNotRunning:(NSString *)bundleID
{
  return [[self.simulator
    runningApplicationWithBundleID:bundleID]
    onQueue:self.simulator.workQueue chain:^(FBFuture<FBProcessInfo *> *future){
      FBProcessInfo *process = future.result;
      if (process) {
        return [[FBSimulatorError
          describeFormat:@"App %@ can't be launched as is running (%@)", bundleID, process.shortDescription]
          failFuture];
      }
      return [FBFuture futureWithResult:NSNull.null];
    }];
}

@end

@implementation FBApplicationLaunchStrategy_Bridge

- (FBFuture<NSNumber *> *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath
{
  // The Bridge must be connected in order for the launch to work.
  FBSimulator *simulator = self.simulator;
  return [[simulator
    connectToBridge]
    onQueue:simulator.workQueue fmap:^(FBSimulatorBridge *bridge) {
      return [bridge launch:appLaunch stdOutPath:stdOutPath stdErrPath:stdErrPath];
    }];
}

@end

@implementation FBApplicationLaunchStrategy_CoreSimulator

- (FBFuture<NSNumber *> *)launchApplication:(FBApplicationLaunchConfiguration *)appLaunch stdOutPath:(NSString *)stdOutPath stdErrPath:(NSString *)stdErrPath
{
  FBSimulator *simulator = self.simulator;
  NSDictionary<NSString *, id> *options = [appLaunch
    simDeviceLaunchOptionsWithStdOutPath:[self translateAbsolutePath:stdOutPath toPathRelativeTo:simulator.dataDirectory]
    stdErrPath:[self translateAbsolutePath:stdErrPath toPathRelativeTo:simulator.dataDirectory]
    waitForDebugger:appLaunch.waitForDebugger];

  FBMutableFuture<NSNumber *> *future = [FBMutableFuture future];
  [simulator.device launchApplicationAsyncWithID:appLaunch.bundleID options:options completionQueue:simulator.workQueue completionHandler:^(NSError *error, pid_t pid){
    if (error) {
      [future resolveWithError:error];
    } else {
      [future resolveWithResult:@(pid)];
    }
  }];
  return future;
}

- (NSString *)translateAbsolutePath:(NSString *)absolutePath toPathRelativeTo:(NSString *)referencePath
{
  if (![absolutePath hasPrefix:@"/"]) {
    return absolutePath;
  }
  // When launching an application with a custom stdout/stderr path, `SimDevice` uses the given path relative
  // to the Simulator's data directory. From the Framework's consumer point of view this might not be the
  // wanted behaviour. To work around it, we construct a path relative to the Simulator's data directory
  // using `..` until we end up in the absolute path outside the Simulator's data directory.
  NSString *translatedPath = @"";
  for (NSUInteger index = 0; index < referencePath.pathComponents.count; index++) {
    translatedPath = [translatedPath stringByAppendingPathComponent:@".."];
  }
  return [translatedPath stringByAppendingPathComponent:absolutePath];
}

@end
