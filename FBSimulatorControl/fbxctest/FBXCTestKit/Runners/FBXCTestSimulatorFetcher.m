/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestSimulatorFetcher.h"

#import <FBSimulatorControl/FBSimulatorControl.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

#import "FBXCTestCommandLine.h"
#import "FBXCTestDestination.h"
#import "FBXCTestSimulatorConfigurator.h"

@interface FBXCTestSimulatorFetcher ()

@property (nonatomic, strong, readonly) FBSimulatorControl *simulatorControl;
@property (nonatomic, copy, readonly) NSArray<id<FBXCTestSimulatorConfigurator>> *configurators;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;

@end

@implementation FBXCTestSimulatorFetcher

#pragma mark Initializers

+ (nullable instancetype)fetcherWithWorkingDirectory:(NSString *)workingDirectory
                           simulatorManagementOptios:(FBSimulatorManagementOptions)simulatorManagementOptions
                                       configurators:(NSArray<id<FBXCTestSimulatorConfigurator>> *)configurators
                                              logger:(id<FBControlCoreLogger>)logger
                                               error:(NSError **)error
{
  NSString *setPath = [workingDirectory stringByAppendingPathComponent:@"sim"];
  FBSimulatorControlConfiguration *controlConfiguration = [FBSimulatorControlConfiguration
    configurationWithDeviceSetPath:setPath
    options:simulatorManagementOptions];

  NSError *innerError = nil;
  FBSimulatorControl *simulatorControl = [FBSimulatorControl withConfiguration:controlConfiguration logger:logger error:&innerError];
  if (!simulatorControl) {
    return [FBXCTestError failWithError:innerError errorOut:error];
  }

  return [[self alloc] initWithSimulatorControl:simulatorControl configurators:configurators logger:logger];
}

- (instancetype)initWithSimulatorControl:(FBSimulatorControl *)simulatorControl
                           configurators:(NSArray<id<FBXCTestSimulatorConfigurator>> *)configurators
                                  logger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _simulatorControl = simulatorControl;
  _configurators = [NSArray arrayWithArray:configurators];
  _logger = logger;

  return self;
}

#pragma mark Public Methods

- (FBFuture<FBSimulator *> *)fetchSimulatorForCommandLine:(FBXCTestCommandLine *)commandLine
{
  FBXCTestDestinationiPhoneSimulator *destination = (FBXCTestDestinationiPhoneSimulator *) commandLine.destination;
  if (![destination isKindOfClass:FBXCTestDestinationiPhoneSimulator.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Simulator Destination", destination]
      failFuture];
  }

  if ([commandLine.configuration isKindOfClass:FBTestManagerTestConfiguration.class]) {
    return [self fetchSimulatorForApplicationTest:destination];
  }
  return [self fetchSimulatorForLogicTest:destination];
}

- (FBFuture<FBSimulator *> *)fetchSimulatorForLogicTest:(FBXCTestDestinationiPhoneSimulator *)destination
{
  FBSimulatorConfiguration *configuration = [FBXCTestSimulatorFetcher configurationForDestination:destination];
  return [self.simulatorControl.pool
    allocateSimulatorWithConfiguration:configuration
    options:FBSimulatorAllocationOptionsReuse];
}

- (FBFuture<FBSimulator *> *)fetchSimulatorForApplicationTest:(FBXCTestDestinationiPhoneSimulator *)destination
{
  FBSimulatorBootConfiguration *bootConfiguration = [[FBSimulatorBootConfiguration
    defaultConfiguration]
    withOptions:FBSimulatorBootOptionsEnableDirectLaunch | FBSimulatorBootOptionsVerifyUsable];
  
  return
  [[[self fetchSimulatorForLogicTest:destination]
   onQueue:dispatch_get_main_queue() fmap:^(FBSimulator *simulator) {
     return [[simulator bootWithConfiguration:bootConfiguration] mapReplace:simulator];
   }] onQueue:dispatch_get_main_queue() fmap:^(FBSimulator *result) {
       NSMutableArray *futures = [[NSMutableArray alloc] init];
       for (id<FBXCTestSimulatorConfigurator> configurator in self.configurators) {
           [futures addObject:[configurator configureSimulator:result]];
       }
       if (futures.count == 0) {
           return [FBFuture futureWithResult:result];
       } else {
           return [[FBFuture futureWithFutures:futures] mapReplace:result];
       }
   }];
}

- (FBFuture<NSNull *> *)returnSimulator:(FBSimulator *)simulator
{
  return [self.simulatorControl.pool freeSimulator:simulator];
}

#pragma mark Private

+ (FBSimulatorConfiguration *)configurationForDestination:(FBXCTestDestinationiPhoneSimulator *)destination
{
  FBSimulatorConfiguration *configuration =
    [[FBSimulatorConfiguration withDeviceModel:destination.model] withOSNamed:destination.version];
  return configuration;
}

@end
