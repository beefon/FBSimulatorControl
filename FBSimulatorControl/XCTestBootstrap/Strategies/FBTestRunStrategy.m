/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTestRunStrategy.h"

#import <XCTestBootstrap/XCTestBootstrap.h>

@interface FBTestRunStrategy ()

@property (nonatomic, strong, readonly) id<FBiOSTarget> target;
@property (nonatomic, strong, readonly) FBTestManagerTestConfiguration *configuration;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;
@property (nonatomic, strong, readonly) id<FBXCTestReporter> reporter;
@property (nonatomic, strong, readonly) Class<FBXCTestPreparationStrategy> testPreparationStrategyClass;
@end

@implementation FBTestRunStrategy

+ (instancetype)strategyWithTarget:(id<FBiOSTarget>)target configuration:(FBTestManagerTestConfiguration *)configuration reporter:(id<FBXCTestReporter>)reporter logger:(id<FBControlCoreLogger>)logger testPreparationStrategyClass:(Class<FBXCTestPreparationStrategy>)testPreparationStrategyClass
{
  return [[self alloc] initWithTarget:target configuration:configuration reporter:reporter logger:logger testPreparationStrategyClass:testPreparationStrategyClass];
}

- (instancetype)initWithTarget:(id<FBiOSTarget>)target configuration:(FBTestManagerTestConfiguration *)configuration reporter:(id<FBXCTestReporter>)reporter logger:(id<FBControlCoreLogger>)logger testPreparationStrategyClass:(Class<FBXCTestPreparationStrategy>)testPreparationStrategyClass
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _target = target;
  _configuration = configuration;
  _reporter = reporter;
  _logger = logger;
  _testPreparationStrategyClass = testPreparationStrategyClass;
  return self;
}

#pragma mark FBXCTestRunner

- (FBFuture<NSNull *> *)execute
{
  __block NSError *error = nil;
  FBApplicationBundle *testRunnerApp = [FBApplicationBundle applicationWithPath:self.configuration.runnerAppPath error:&error];
  if (!testRunnerApp) {
    [self.logger logFormat:@"Failed to open test runner application: %@", error];
    return [FBFuture futureWithError:error];
  }

  FBApplicationBundle *testTargetApp;
  if (self.configuration.testTargetAppPath) {
    testTargetApp = [FBApplicationBundle applicationWithPath:self.configuration.testTargetAppPath error:&error];
    if (!testTargetApp) {
      [self.logger logFormat:@"Failed to open test target application: %@", error];
      return [FBFuture futureWithError:error];
    }
  }
  
  NSMutableArray<FBApplicationBundle *> *additionalApplications = [NSMutableArray arrayWithCapacity:self.configuration.additionalApplicationPaths.count];
  for (NSString *path in self.configuration.additionalApplicationPaths) {
    FBApplicationBundle *app = [FBApplicationBundle applicationWithPath:path error:&error];
    if (!app) {
      [self.logger logFormat:@"Failed to open additional application: %@", error];
      return [FBFuture futureWithError:error];
    } else {
      [additionalApplications addObject:app];
    }
  }
  
  return [[self.target
    installApplicationWithPath:testRunnerApp.path]
    onQueue:self.target.workQueue fmap:^(id _) {
      return [self startTestWithTestRunnerApp:testRunnerApp testTargetApp:testTargetApp additionalApplications:additionalApplications];
    }];
}

#pragma mark Private

- (FBFuture<NSNull *> *)startTestWithTestRunnerApp:(FBApplicationBundle *)testRunnerApp testTargetApp:(FBApplicationBundle *)testTargetApp additionalApplications:(NSArray<FBApplicationBundle *> *)additionalApplications
{
  FBProcessOutputConfiguration *outputConfiguration = FBProcessOutputConfiguration.outputToDevNull;
  if (self.configuration.runnerAppLogPath != nil) {
    outputConfiguration = [FBProcessOutputConfiguration configurationWithStdOut:self.configuration.runnerAppLogPath
                                                                         stdErr:self.configuration.runnerAppLogPath
                                                                          error:NULL];
  }
  FBApplicationLaunchConfiguration *appLaunch = [FBApplicationLaunchConfiguration
    configurationWithApplication:testRunnerApp
    arguments:@[]
    environment:self.configuration.processUnderTestEnvironment
    waitForDebugger:NO
    output:outputConfiguration];

  FBTestLaunchConfiguration *testLaunchConfiguration = [[FBTestLaunchConfiguration
    configurationWithTestBundlePath:self.configuration.testBundlePath]
    withApplicationLaunchConfiguration:appLaunch];

  if (testTargetApp) {
    testLaunchConfiguration = [[[[testLaunchConfiguration
     withTargetApplicationPath:testTargetApp.path]
     withTargetApplicationBundleID:testTargetApp.bundleID]
     withTestApplicationDependencies:[self _testApplicationDependenciesWithTestRunnerApp:testRunnerApp testTargetApp:testTargetApp additionalApplications:additionalApplications]]
     withUITesting:YES];
  }

  if (self.configuration.testFilters.count > 0) {
    NSSet<NSString *> *testsToRun = [NSSet setWithArray:self.configuration.testFilters];
    testLaunchConfiguration = [testLaunchConfiguration withTestsToRun:testsToRun];
  }

  id<FBXCTestPreparationStrategy> testPreparationStrategy = [self.testPreparationStrategyClass
    strategyWithTestLaunchConfiguration:testLaunchConfiguration
    workingDirectory:[self.configuration.workingDirectory stringByAppendingPathComponent:@"tmp"]];

  FBManagedTestRunStrategy *runner = [FBManagedTestRunStrategy
    strategyWithTarget:self.target
    configuration:testLaunchConfiguration
    reporter:[FBXCTestReporterAdapter adapterWithReporter:self.reporter]
    logger:self.target.logger
    testPreparationStrategy:testPreparationStrategy];

  __block id<FBiOSTargetContinuation> tailLogContinuation = nil;

  return [[[[[runner
    connectAndStart]
    onQueue:self.target.workQueue fmap:^(FBTestManager *manager) {
      FBFuture *startedVideoRecording = self.configuration.videoRecordingPath != nil
        ? [self.target startRecordingToFile:self.configuration.videoRecordingPath]
        : [FBFuture futureWithResult:NSNull.null];

      FBFuture *startedTailLog = self.configuration.osLogPath != nil
        ? [self _startTailLogToFile:self.configuration.osLogPath]
        : [FBFuture futureWithResult:NSNull.null];

      return [FBFuture futureWithFutures:@[[FBFuture futureWithResult:manager], startedVideoRecording, startedTailLog]];
    }]
    onQueue:self.target.workQueue fmap:^(NSArray<id> *results) {
      FBTestManager *manager = results[0];
      if (results[2] != nil && ![results[2] isEqual:NSNull.null]) {
        tailLogContinuation = results[2];
      }
      return [manager execute];
    }]
    onQueue:self.target.workQueue fmap:^(FBTestManagerResult *result) {
      FBFuture *stoppedVideoRecording = self.configuration.videoRecordingPath != nil
        ? [self.target stopRecording]
        : [FBFuture futureWithResult:NSNull.null];
      FBFuture *stopTailLog = tailLogContinuation != nil
        ? [tailLogContinuation.completed cancel]
        : [FBFuture futureWithResult:NSNull.null];
      return [FBFuture futureWithFutures:@[[FBFuture futureWithResult:result], stoppedVideoRecording, stopTailLog]];
    }]
    onQueue:self.target.workQueue fmap:^(NSArray<id> *results) {
      FBTestManagerResult *result = results[0];
      if (self.configuration.videoRecordingPath != nil) {
        [self.reporter didRecordVideoAtPath:self.configuration.videoRecordingPath];
      }

      if (self.configuration.osLogPath != nil) {
        [self.reporter didSaveOSLogAtPath:self.configuration.osLogPath];
      }
      
      if (self.configuration.runnerAppLogPath != nil) {
        [self.reporter didSaveRunnerAppLogAtPath:self.configuration.runnerAppLogPath];
      }

      if (self.configuration.testArtifactsFilenameGlobs != nil) {
        [self _saveTestArtifactsOfTestRunnerApp:testRunnerApp withFilenameMatchGlobs:self.configuration.testArtifactsFilenameGlobs];
      }

      if (result.crashDiagnostic) {
        return [[FBXCTestError
          describeFormat:@"The Application Crashed during the Test Run\n%@", result.crashDiagnostic.asString]
          failFuture];
      }
      if (result.error) {
        [self.logger logFormat:@"Failed to execute test bundle %@", result.error];
        return [FBFuture futureWithError:result.error];
      }
      return [FBFuture futureWithResult:NSNull.null];
    }];
}

- (NSDictionary<NSString *, NSString *> *)_testApplicationDependenciesWithTestRunnerApp:(FBApplicationBundle *)testRunnerApp testTargetApp:(FBApplicationBundle *)testTargetApp additionalApplications:(NSArray<FBApplicationBundle *> *)additionalApplications
{
  NSMutableArray<FBApplicationBundle *> *allApplications = [additionalApplications mutableCopy];
  if (testRunnerApp) {
    [allApplications addObject:testRunnerApp];
  }
  if (testTargetApp) {
    [allApplications addObject:testTargetApp];
  }
  NSMutableDictionary<NSString *, NSString *> *testApplicationDependencies = [NSMutableDictionary new];
  for (FBApplicationBundle *application in allApplications) {
    if (application.path != nil && application.bundleID != nil) {
      [testApplicationDependencies setObject:application.path forKey:application.bundleID];
    }
  }
  return [testApplicationDependencies copy];
}

// Save test artifacts matches certain filename globs that are populated during test run
// to a temporary folder so it can be obtained by external tools if needed.
- (void)_saveTestArtifactsOfTestRunnerApp:(FBApplicationBundle *)testRunnerApp withFilenameMatchGlobs:(NSArray<NSString *> *)filenameGlobs
{
  NSArray<FBDiagnostic *> *diagnostics = [[[FBDiagnosticQuery
    filesInApplicationOfBundleID:testRunnerApp.bundleID withFilenames:@[] withFilenameGlobs:filenameGlobs]
    run:self.target]
    await:nil];

  if ([diagnostics count] == 0) {
    return;
  }

  NSURL *tempTestArtifactsPath = [NSURL fileURLWithPath:[NSString pathWithComponents:@[NSTemporaryDirectory(), NSProcessInfo.processInfo.globallyUniqueString, @"test_artifacts"]] isDirectory:YES];

  NSError *error = nil;
  if (![NSFileManager.defaultManager createDirectoryAtURL:tempTestArtifactsPath withIntermediateDirectories:YES attributes:nil error:&error]) {
    [self.logger logFormat:@"Could not create temporary directory for test artifacts %@", error];
    return;
  }

  for (FBDiagnostic *diagnostic in diagnostics) {
    NSString *testArtifactsFilename = diagnostic.asPath.lastPathComponent;
    NSString *outputPath = [tempTestArtifactsPath.path stringByAppendingPathComponent:testArtifactsFilename];
    if ([diagnostic writeOutToFilePath:outputPath error:nil]) {
      [self.reporter didCopiedTestArtifact:testArtifactsFilename toPath:outputPath];
    }
  }
}

- (FBFuture *)_startTailLogToFile:(NSString *)logFilePath
{
  NSError *error = nil;
  FBFileWriter *logFileWriter = [FBFileWriter syncWriterForFilePath:logFilePath error:&error];
  if (logFileWriter == nil) {
    [self.logger logFormat:@"Could not create log file at %@: %@", self.configuration.osLogPath, error];
    return [FBFuture futureWithResult:NSNull.null];
  }

  return [self.target tailLog:@[@"--style", @"syslog", @"--level", @"debug"] consumer:logFileWriter];
}

@end
