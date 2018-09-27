/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBManagedTestRunStrategy.h"

#import <FBControlCore/FBControlCore.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

@interface FBManagedTestRunStrategy ()

@property (nonatomic, strong, readonly) id<FBiOSTarget> target;

@property (nonatomic, strong, nullable, readonly) FBTestLaunchConfiguration *configuration;
@property (nonatomic, strong, nullable, readonly) id<FBTestManagerTestReporter> reporter;
@property (nonatomic, strong, nullable, readonly) id<FBControlCoreLogger> logger;
@property (nonatomic, strong, nullable, readonly) id<FBXCTestPreparationStrategy> testPreparationStrategy;

@end

@implementation FBManagedTestRunStrategy

#pragma mark Initializers

+ (instancetype)strategyWithTarget:(id<FBiOSTarget>)target configuration:(FBTestLaunchConfiguration *)configuration reporter:(id<FBTestManagerTestReporter>)reporter logger:(id<FBControlCoreLogger>)logger testPreparationStrategy:(id<FBXCTestPreparationStrategy>)testPreparationStrategy
{
  NSParameterAssert(target);

  return [[self alloc] initWithConfiguration:configuration target:target reporter:reporter logger:logger testPreparationStrategy:testPreparationStrategy];
}

- (instancetype)initWithConfiguration:(FBTestLaunchConfiguration *)configuration target:(id<FBiOSTarget>)target reporter:(id<FBTestManagerTestReporter>)reporter logger:(id<FBControlCoreLogger>)logger testPreparationStrategy:(id<FBXCTestPreparationStrategy>)testPreparationStrategy
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _configuration = configuration;
  _reporter = reporter;
  _target = target;
  _logger = logger;
  _testPreparationStrategy = testPreparationStrategy;

  return self;
}

#pragma mark Public Methods

- (FBFuture<FBTestManager *> *)connectAndStart
{
  NSParameterAssert(self.configuration.applicationLaunchConfiguration);
  NSParameterAssert(self.configuration.testBundlePath);

  NSError *error = nil;
  if (![XCTestBootstrapFrameworkLoader.allDependentFrameworks loadPrivateFrameworks:self.target.logger error:&error]) {
    return [XCTestBootstrapError failFutureWithError:error];
  }

  FBXCTestRunStrategy *testRunStrategy = [FBXCTestRunStrategy
    strategyWithIOSTarget:self.target
    testPrepareStrategy:self.testPreparationStrategy
    reporter:self.reporter
    logger:self.logger];

  FBFuture<FBTestManager *> *runFuture = [[testRunStrategy
    startTestManagerWithApplicationLaunchConfiguration:self.configuration.applicationLaunchConfiguration]
    onQueue:self.target.workQueue fmap:^(FBTestManager *testManager) {
      FBFuture<FBTestManagerResult *> *result = [testManager execute];
      [result onQueue:dispatch_get_main_queue()
   notifyOfCompletion:^(FBFuture<FBTestManagerResult *> * _Nonnull finishedResult) {
     if (!finishedResult.result.didEndSuccessfully) {
       [self.logger.error logFormat:@"Test plan did not finish successfully: %@", finishedResult];
       [self.reporter testManagerMediator:nil
               testPlanDidFailWithMessage:
        [NSString stringWithFormat:@"Test plan did not finish successfully: %@", finishedResult]];
     }
        
      }];
      if (result.error) {
        return [FBFuture futureWithError:result.error];
      }
      return [FBFuture futureWithResult:testManager];
    }];
  return runFuture;
}

@end
