/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestConfiguration.h"
#import "FBXCTestProcess.h"
#import "FBXCTestProcessExecutor.h"
#import "FBXCTestShimConfiguration.h"
#import "XCTestBootstrapError.h"

FBXCTestType const FBXCTestTypeApplicationTest = FBXCTestTypeApplicationTestValue;
FBXCTestType const FBXCTestTypeLogicTest = @"logic-test";
FBXCTestType const FBXCTestTypeListTest = @"list-test";
FBXCTestType const FBXCTestTypeUITest = @"ui-test";

@implementation FBXCTestConfiguration

#pragma mark Initializers

- (instancetype)initWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _shims = shims;
  _processUnderTestEnvironment = environment ?: @{};
  _workingDirectory = workingDirectory;
  _testBundlePath = testBundlePath;
  _waitForDebugger = waitForDebugger;

  NSString *timeoutFromEnv = NSProcessInfo.processInfo.environment[@"FB_TEST_TIMEOUT"];
  if (timeoutFromEnv) {
    _testTimeout = timeoutFromEnv.intValue;
  } else {
    _testTimeout = timeout > 0 ? timeout : [self defaultTimeout];
  }

  return self;
}

#pragma mark Public

- (NSTimeInterval)defaultTimeout
{
  return 500;
}

- (NSString *)testType
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

- (NSDictionary<NSString *, NSString *> *)buildEnvironmentWithEntries:(NSDictionary<NSString *, NSString *> *)entries
{
  NSMutableDictionary<NSString *, NSString *> *parentEnvironment = NSProcessInfo.processInfo.environment.mutableCopy;
  [parentEnvironment removeObjectsForKeys:@[
    @"XCTestConfigurationFilePath",
  ]];

  NSMutableDictionary<NSString *, NSString *> *environmentOverrides = [NSMutableDictionary dictionary];
  NSString *xctoolTestEnvPrefix = @"XCTOOL_TEST_ENV_";
  for (NSString *key in parentEnvironment) {
    if ([key hasPrefix:xctoolTestEnvPrefix]) {
      NSString *childKey = [key substringFromIndex:xctoolTestEnvPrefix.length];
      environmentOverrides[childKey] = parentEnvironment[key];
    }
  }
  [environmentOverrides addEntriesFromDictionary:entries];
  NSMutableDictionary<NSString *, NSString *> *environment = parentEnvironment.mutableCopy;
  for (NSString *key in environmentOverrides) {
    NSString *childKey = key;
    environment[childKey] = environmentOverrides[key];
  }
  return environment.copy;
}

#pragma mark NSObject

- (NSString *)description
{
  return [self.jsonSerializableRepresentation description];
}

- (BOOL)isEqual:(FBXCTestConfiguration *)object
{
  // Class must match exactly in the class-cluster
  if (![object isMemberOfClass:self.class]) {
    return NO;
  }
  return (self.shims == object.shims || [self.shims isEqual:object.shims])
      && (self.processUnderTestEnvironment == object.processUnderTestEnvironment || [self.processUnderTestEnvironment isEqualToDictionary:object.processUnderTestEnvironment])
      && (self.workingDirectory == object.workingDirectory || [self.workingDirectory isEqualToString:object.workingDirectory])
      && (self.testBundlePath == object.testBundlePath || [self.testBundlePath isEqualToString:object.testBundlePath])
      && (self.testType == object.testType || [self.testType isEqualToString:object.testType])
      && (self.waitForDebugger == object.waitForDebugger)
      && (self.testTimeout == object.testTimeout);
}

- (NSUInteger)hash
{
  return self.shims.hash ^ self.processUnderTestEnvironment.hash ^ self.workingDirectory.hash ^ self.testBundlePath.hash ^ self.testType.hash ^ ((NSUInteger) self.waitForDebugger) ^ ((NSUInteger) self.testTimeout);
}

#pragma mark JSON

NSString *const KeyEnvironment = @"environment";
NSString *const KeyListTestsOnly = @"list_only";
NSString *const KeyOSLogPath = @"os_log_path";
NSString *const KeyRunnerLogPath = @"runner_log_path";
NSString *const KeyApplicationLogPath = @"application_log_path";
NSString *const KeyRunnerAppPath = @"test_host_path";
NSString *const KeyRunnerTargetPath = @"test_target_path";
NSString *const KeyAdditionalApplicationPaths = @"additional_application_paths";
NSString *const KeyShims = @"shims";
NSString *const KeyTestArtifactsFilenameGlobs = @"test_artifacts_filename_globs";
NSString *const KeyTestBundlePath = @"test_bundle_path";
NSString *const KeyTestFilter = @"test_filter";
NSString *const KeyTestMirror = @"test_mirror";
NSString *const KeyTestTimeout = @"test_timeout";
NSString *const KeyTestType = @"test_type";
NSString *const KeyVideoRecordingPath = @"video_recording_path";
NSString *const KeyWaitForDebugger = @"wait_for_debugger";
NSString *const KeyWorkingDirectory = @"working_directory";

- (id)jsonSerializableRepresentation
{
  return @{
    KeyShims: self.shims.jsonSerializableRepresentation ?: NSNull.null,
    KeyEnvironment: self.processUnderTestEnvironment,
    KeyWorkingDirectory: self.workingDirectory,
    KeyTestBundlePath: self.testBundlePath,
    KeyTestType: self.testType,
    KeyListTestsOnly: @NO,
    KeyWaitForDebugger: @(self.waitForDebugger),
    KeyTestTimeout: @(self.testTimeout),
  };
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json error:(NSError **)error
{
  if (![FBCollectionInformation isDictionaryHeterogeneous:json keyClass:NSString.class valueClass:NSObject.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Dictionary<String, Any>", json]
      fail:error];
  }
  NSString *testType = json[KeyTestType];
  if (![testType isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", testType, KeyTestType]
      fail:error];
  }
  NSNumber *listTestsOnly = json[KeyListTestsOnly] ?: @NO;
  if (![listTestsOnly isKindOfClass:NSNumber.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Number for %@", listTestsOnly, KeyListTestsOnly]
      fail:error];
  }
  NSDictionary<NSString *, NSString *> *environment = json[KeyEnvironment];
  if (![FBCollectionInformation isDictionaryHeterogeneous:environment keyClass:NSString.class valueClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Dictionary<String, String> for %@", environment, KeyEnvironment]
      fail:error];
  }
  NSString *workingDirectory = json[KeyWorkingDirectory];
  if (![workingDirectory isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", workingDirectory, KeyWorkingDirectory]
      fail:error];
  }
  NSString *testBundlePath = json[KeyTestBundlePath];
  if (![testBundlePath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", testBundlePath, KeyTestBundlePath]
      fail:error];
  }
  NSNumber *waitForDebugger = [FBCollectionOperations nullableValueForDictionary:json key:KeyWaitForDebugger] ?: @NO;
  if (![waitForDebugger isKindOfClass:NSNumber.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Number for %@", waitForDebugger, KeyWaitForDebugger]
      fail:error];
  }
  NSNumber *testTimeout = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestTimeout] ?: @0;
  if (![testTimeout isKindOfClass:NSNumber.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Number for %@", testTimeout, KeyTestTimeout]
      fail:error];
  }
  NSDictionary<NSString *, id> *shimsDictionary = [FBCollectionOperations nullableValueForDictionary:json key:KeyShims];
  if (shimsDictionary && ![FBCollectionInformation isDictionaryHeterogeneous:shimsDictionary keyClass:NSString.class valueClass:NSObject.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Dictonary<String, String> for %@", shimsDictionary, KeyShims]
      fail:error];
  }
  FBXCTestShimConfiguration *shims = nil;
  if (shimsDictionary) {
    shims = [FBXCTestShimConfiguration inflateFromJSON:shimsDictionary error:error];
    if (!shims) {
      return nil;
    }
  }
  Class clusterClass = nil;
  if ([testType isEqualToString:FBXCTestTypeListTest]) {
    clusterClass = FBListTestConfiguration.class;
  } else if ([testType isEqualToString:FBXCTestTypeLogicTest]) {
    clusterClass = listTestsOnly.boolValue ? FBListTestConfiguration.class : FBLogicTestConfiguration.class;
  } else if ([testType isEqualToString:FBXCTestTypeApplicationTest]) {
    clusterClass = FBTestManagerTestConfiguration.class;
  } else if ([testType isEqualToString:FBXCTestTypeUITest]) {
    clusterClass = FBTestManagerTestConfiguration.class;
  } else {
    return [[FBControlCoreError
      describeFormat:@"Test Type %@ is not a value Test Type for %@", testType, KeyTestType]
      fail:error];
  }
  return [clusterClass
    inflateFromJSON:json
    shims:shims
    environment:environment
    workingDirectory:workingDirectory
    testBundlePath:testBundlePath
    waitForDebugger:waitForDebugger.boolValue
    timeout:testTimeout.doubleValue
    error:nil];
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json shims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout error:(NSError **)error
{
  return [[self alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return self;
}

@end

@implementation FBListTestConfiguration {
  NSString *_runnerAppPath;
}

#pragma mark Initializers

+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath runnerAppPath:(nullable NSString *)runnerAppPath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout
{
  return [[FBListTestConfiguration alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath runnerAppPath:runnerAppPath waitForDebugger:waitForDebugger timeout:timeout];
}

- (instancetype)initWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath runnerAppPath:(nullable NSString *)runnerAppPath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout
{
  self = [super initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout];
  if (!self) {
    return nil;
  }

  _runnerAppPath = runnerAppPath;

  return self;
}

#pragma mark Public

- (NSString *)testType
{
  return FBXCTestTypeListTest;
}

- (FBFuture<id<FBLaunchedProcess>> *)listTestProcessWithEnvironment:(NSDictionary<NSString *, NSString *> *)environment stdOutConsumer:(id<FBFileConsumer>)stdOutConsumer stdErrConsumer:(id<FBFileConsumer>)stdErrConsumer executor:(id<FBXCTestProcessExecutor>)executor logger:(id<FBControlCoreLogger>)logger
{
  if ([FBApplicationBundle isApplicationAtPath:_runnerAppPath]) {
    // List test for app test bundle, so we use app binary instead of xctest to load test bundle.
    NSString *xcTestFrameworkPath =
    [[FBXcodeConfiguration.developerDirectory
      stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform"]
      stringByAppendingPathComponent:@"Developer/Library/Frameworks/XCTest.framework"];

    // Since we spawn process using app binary directly without installation, we need to manully copy
    // xctest framework to app's rpath so it can be found by dyld when we load test bundle later.
    [FBApplicationBundle copyFrameworkToApplicationAtPath:_runnerAppPath frameworkPath:xcTestFrameworkPath];

    FBApplicationBundle *appBundle = [FBApplicationBundle applicationWithPath:_runnerAppPath error:nil];
    return [FBXCTestProcess
      startWithLaunchPath:appBundle.binary.path
      arguments:@[]
      environment:environment
      waitForDebugger:NO
      stdOutConsumer:stdOutConsumer
      stdErrConsumer:stdErrConsumer
      executor:executor
      timeout:self.testTimeout
      logger:logger];
  }

  NSString *xctestPath = executor.xctestPath;
  NSArray<NSString *> *arguments = @[@"-XCTest", @"All", self.testBundlePath];
  return [FBXCTestProcess
    startWithLaunchPath:xctestPath
    arguments:arguments
    environment:environment
    waitForDebugger:NO
    stdOutConsumer:stdOutConsumer
    stdErrConsumer:stdErrConsumer
    executor:executor
    timeout:self.testTimeout
    logger:logger];
}

#pragma mark JSON

- (id)jsonSerializableRepresentation
{
  NSMutableDictionary<NSString *, id> *json = [NSMutableDictionary dictionaryWithDictionary:[super jsonSerializableRepresentation]];
  json[KeyListTestsOnly] = @YES;
  json[KeyRunnerAppPath] = _runnerAppPath ?: NSNull.null;
  return [json copy];
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json shims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout error:(NSError **)error
{
  NSString *runnerAppPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyRunnerAppPath];
  if (runnerAppPath && ![runnerAppPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a String for %@", runnerAppPath, KeyRunnerAppPath]
            fail:error];
  }
  return [[FBListTestConfiguration alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath runnerAppPath:runnerAppPath waitForDebugger:waitForDebugger timeout:timeout];
}

@end

@implementation FBTestManagerTestConfiguration

#pragma mark Initializers

+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout runnerAppPath:(NSString *)runnerAppPath testTargetAppPath:(nullable NSString *)testTargetAppPath testFilters:(NSArray<NSString *> *)testFilters videoRecordingPath:(nullable NSString *)videoRecordingPath testArtifactsFilenameGlobs:(nullable NSArray<NSString *> *)testArtifactsFilenameGlobs osLogPath:(nullable NSString *)osLogPath additionalApplicationPaths:(NSArray<NSString *> *)additionalApplicationPaths runnerAppLogPath:(nullable NSString *)runnerAppLogPath applicationLogPath:(nullable NSString *)applicationLogPath
{
    return [[FBTestManagerTestConfiguration alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout runnerAppPath:runnerAppPath testTargetAppPath:testTargetAppPath testFilters:testFilters videoRecordingPath:videoRecordingPath testArtifactsFilenameGlobs:testArtifactsFilenameGlobs osLogPath:osLogPath additionalApplicationPaths:additionalApplicationPaths runnerAppLogPath:runnerAppLogPath applicationLogPath:applicationLogPath];
}

- (instancetype)initWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout runnerAppPath:(NSString *)runnerAppPath testTargetAppPath:(nullable NSString *)testTargetAppPath testFilters:(NSArray<NSString *> *)testFilters videoRecordingPath:(nullable NSString *)videoRecordingPath testArtifactsFilenameGlobs:(NSArray<NSString *> *)testArtifactsFilenameGlobs osLogPath:(nullable NSString *)osLogPath additionalApplicationPaths:(NSArray<NSString *> *)additionalApplicationPaths runnerAppLogPath:(nullable NSString *)runnerAppLogPath applicationLogPath:(nullable NSString *)applicationLogPath
{
  self = [super initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout];
  if (!self) {
    return nil;
  }

  _runnerAppPath = runnerAppPath;
  _testTargetAppPath = testTargetAppPath;
  _additionalApplicationPaths = [additionalApplicationPaths copy];
  _testFilters = [NSArray arrayWithArray:testFilters];
  _videoRecordingPath = videoRecordingPath;
  _testArtifactsFilenameGlobs = testArtifactsFilenameGlobs;
  _osLogPath = osLogPath;
  _runnerAppLogPath = runnerAppLogPath;
  _applicationLogPath = applicationLogPath;

  return self;
}

#pragma mark Public

- (NSString *)testType
{
  return _testTargetAppPath != nil ? FBXCTestTypeUITest : FBXCTestTypeApplicationTest;
}

#pragma mark JSON

- (id)jsonSerializableRepresentation
{
  NSMutableDictionary<NSString *, id> *json = [NSMutableDictionary dictionaryWithDictionary:[super jsonSerializableRepresentation]];
  json[KeyRunnerAppPath] = self.runnerAppPath;
  json[KeyRunnerTargetPath] = self.testTargetAppPath;
  json[KeyAdditionalApplicationPaths] = self.additionalApplicationPaths;
  json[KeyTestFilter] = self.testFilters ?: NSNull.null;
  json[KeyVideoRecordingPath] = self.videoRecordingPath ?: NSNull.null;
  json[KeyTestArtifactsFilenameGlobs] = self.testArtifactsFilenameGlobs ?: NSNull.null;
  json[KeyOSLogPath] =  self.osLogPath ?: NSNull.null;
  json[KeyRunnerLogPath] =  self.runnerAppLogPath ?: NSNull.null;
  json[KeyApplicationLogPath] =  self.applicationLogPath ?: NSNull.null;
  return [json copy];
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json shims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout error:(NSError **)error
{
  NSString *runnerAppPath = json[KeyRunnerAppPath];
  if (![runnerAppPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", runnerAppPath, KeyRunnerAppPath]
      fail:error];
  }
  NSString *testTargetAppPath = json[KeyRunnerTargetPath];
  if (testTargetAppPath != nil && ![testTargetAppPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a String for %@", testTargetAppPath, KeyRunnerTargetPath]
      fail:error];
  }
  NSArray *additionalApplicationPaths = [FBCollectionOperations nullableValueForDictionary:json key:KeyAdditionalApplicationPaths];
  if (additionalApplicationPaths && ![additionalApplicationPaths isKindOfClass:NSArray.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a Array for %@", additionalApplicationPaths, KeyAdditionalApplicationPaths]
            fail:error];
  }
  NSArray *testFilters = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestFilter];
  if (testFilters && ![testFilters isKindOfClass:NSArray.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Array for %@", testFilters, KeyTestFilter]
      fail:error];
  }

  NSString *videoRecordingPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyVideoRecordingPath];
  if (videoRecordingPath && ![videoRecordingPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a String for %@", videoRecordingPath, KeyVideoRecordingPath]
            fail:error];
  }
  NSArray<NSString *> *testArtifactsFilenameGlobs = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestArtifactsFilenameGlobs];
  if (testArtifactsFilenameGlobs && ![testArtifactsFilenameGlobs isKindOfClass:NSArray.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a Array for %@", testArtifactsFilenameGlobs, KeyTestArtifactsFilenameGlobs]
            fail:error];
  }
  NSString *osLogPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyOSLogPath];
  if (osLogPath && ![osLogPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a String for %@", osLogPath, KeyOSLogPath]
            fail:error];
  }
  NSString *runnerAppLogPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyRunnerLogPath];
  if (runnerAppLogPath && ![runnerAppLogPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a String for %@", runnerAppLogPath, KeyRunnerLogPath]
            fail:error];
  }
  NSString *applicationLogPath = [FBCollectionOperations nullableValueForDictionary:json key:KeyApplicationLogPath];
  if (applicationLogPath && ![applicationLogPath isKindOfClass:NSString.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a String for %@", applicationLogPath, KeyApplicationLogPath]
            fail:error];
  }
  
  return [[FBTestManagerTestConfiguration alloc]          
          initWithShims:shims
          environment:environment
          workingDirectory:workingDirectory
          testBundlePath:testBundlePath
          waitForDebugger:waitForDebugger
          timeout:timeout
          runnerAppPath:runnerAppPath
          testTargetAppPath:testTargetAppPath
          testFilters:testFilters
          videoRecordingPath:videoRecordingPath
          testArtifactsFilenameGlobs:testArtifactsFilenameGlobs
          osLogPath:osLogPath
          additionalApplicationPaths:additionalApplicationPaths
          runnerAppLogPath:runnerAppLogPath
          applicationLogPath:applicationLogPath];
}

@end

@implementation FBLogicTestConfiguration

#pragma mark Initializers

+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout testFilters:(NSArray<NSString *> *)testFilters mirroring:(FBLogicTestMirrorLogs)mirroring
{
  return [[FBLogicTestConfiguration alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout testFilters:testFilters mirroring:mirroring];
}

- (instancetype)initWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout testFilters:(NSArray<NSString *> *)testFilters mirroring:(FBLogicTestMirrorLogs)mirroring
{
  self = [super initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout];
  if (!self) {
    return nil;
  }

  _testFilters = testFilters;
  _mirroring = mirroring;

  return self;
}

#pragma mark Public

- (NSString *)testType
{
  return FBXCTestTypeLogicTest;
}

#pragma mark JSON

- (id)jsonSerializableRepresentation
{
  NSMutableDictionary<NSString *, id> *json = [NSMutableDictionary dictionaryWithDictionary:[super jsonSerializableRepresentation]];
  json[KeyTestFilter] = self.testFilters ?: NSNull.null;
  return [json copy];
}

+ (nullable instancetype)inflateFromJSON:(NSDictionary<NSString *, id> *)json shims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout error:(NSError **)error
{
  NSArray *keyTestFilter = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestFilter];
  if (keyTestFilter && ![keyTestFilter isKindOfClass:NSArray.class]) {
    return [[FBXCTestError
      describeFormat:@"%@ is not a Array for %@", keyTestFilter, KeyTestFilter]
      fail:error];
  }
  NSNumber *mirrorOpts = [FBCollectionOperations nullableValueForDictionary:json key:KeyTestMirror];
  if (mirrorOpts && ![mirrorOpts isKindOfClass:NSNumber.class]) {
    return [[FBXCTestError
             describeFormat:@"%@ is not a Number for %@", keyTestFilter, KeyTestFilter]
            fail:error];
  }
  return [[FBLogicTestConfiguration alloc] initWithShims:shims environment:environment workingDirectory:workingDirectory testBundlePath:testBundlePath waitForDebugger:waitForDebugger timeout:timeout testFilters:keyTestFilter mirroring:mirrorOpts.unsignedIntegerValue];
}

@end
