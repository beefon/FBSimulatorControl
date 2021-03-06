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

/**
 A String Enum for Test Types.
 */
typedef NSString *FBXCTestType NS_STRING_ENUM;

/**
 An UITest.
 */
extern FBXCTestType const FBXCTestTypeUITest;

/**
 An Application Test.
 */
#define FBXCTestTypeApplicationTestValue @"application-test"
extern FBXCTestType const FBXCTestTypeApplicationTest;

/**
 A Logic Test.
 */
extern FBXCTestType const FBXCTestTypeLogicTest;

/**
 The Listing of Testing of tests in a bundle.
 */
extern FBXCTestType const FBXCTestTypeListTest;

@class FBXCTestDestination;
@class FBXCTestShimConfiguration;

/**
 The Base Configuration for all tests.
 */
@interface FBXCTestConfiguration : NSObject <NSCopying, FBJSONSerializable, FBJSONDeserializable>

/**
 The Default Initializer.
 This should not be called directly.
 */
- (instancetype)initWithShims:(nullable FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout;

/**
 The Shims to use for relevant test runs.
 */
@property (nonatomic, copy, nullable, readonly) FBXCTestShimConfiguration *shims;

/**
 The Environment Variables for the Process-Under-Test that is launched.
 */
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *processUnderTestEnvironment;

/**
 The Directory to use for files required during the execution of the test run.
 */
@property (nonatomic, copy, readonly) NSString *workingDirectory;

/**
 The Test Bundle to Execute.
 */
@property (nonatomic, copy, readonly) NSString *testBundlePath;

/**
 The Type of the Test Bundle.
 */
@property (nonatomic, copy, readonly) FBXCTestType testType;

/**
 YES if the test execution should pause on launch, waiting for a debugger to attach.
 NO otherwise.
 */
@property (nonatomic, assign, readonly) BOOL waitForDebugger;

/**
 The Timeout to wait for the test execution to finish.
 */
@property (nonatomic, assign, readonly) NSTimeInterval testTimeout;

/**
 Gets the Environment for a Subprocess.
 Will extract the environment variables from the appropriately prefixed environment variables.
 Will strip out environment variables that will confuse subprocesses if this class is called inside an 'xctest' environment.

 @param entries the entries to add in
 @return the subprocess environment
 */
- (NSDictionary<NSString *, NSString *> *)buildEnvironmentWithEntries:(NSDictionary<NSString *, NSString *> *)entries;

@end

@class FBXCTestProcess;

@protocol FBXCTestProcessExecutor;

/**
 A Test Configuration, specialized to the listing of Test Bundles.
 */
@interface FBListTestConfiguration : FBXCTestConfiguration

/**
 The Designated Initializer.
 */
+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath runnerAppPath:(nullable NSString *)runnerAppPath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout;

/**
 Start an xctest process with the given configuration.

 @param environment environment variables passing to the process.
 @param stdOutConsumer the Consumer of the launched process stdout.
 @param stdErrConsumer the Consumer of the launched process stderr.
 @param executor the executor for running the list test process.
 @param logger the logger to log to
 @return the list test process
 */
- (FBFuture<id<FBLaunchedProcess>> *)listTestProcessWithEnvironment:(NSDictionary<NSString *, NSString *> *)environment stdOutConsumer:(id<FBDataConsumer>)stdOutConsumer stdErrConsumer:(id<FBDataConsumer>)stdErrConsumer executor:(id<FBXCTestProcessExecutor>)executor logger:(id<FBControlCoreLogger>)logger;

@end

/**
 A Test Configuration, specialized in running of Tests.
 */
@interface FBTestManagerTestConfiguration : FBXCTestConfiguration

/**
 The Path to the Application Hosting the Test.
 */
@property (nonatomic, copy, readonly) NSString *runnerAppPath;

/**
 The Path to the test target Application.
 */
@property (nonatomic, copy, readonly, nullable) NSString *testTargetAppPath;

/**
 The Paths to the additional Applications that can be launched during tests.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *additionalApplicationPaths;

/**
 The test filters for which test to run.
 Format: <testClass>/<testMethod>
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *testFilters;

/**
 The path of log file that we dump all os_log to.
 (os_log means Apple's unified logging system (https://developer.apple.com/documentation/os/logging),
 we use this name to avoid confusing between various logging systems)
 */
@property (nonatomic, copy, readonly, nullable) NSString *osLogPath;

@property (nonatomic, copy, readonly, nullable) NSString *runnerAppLogPath;
@property (nonatomic, copy, readonly, nullable) NSString *applicationLogPath;

/**
 The path of video recording file that record the whole test run.
 */
@property (nonatomic, copy, readonly, nullable) NSString *videoRecordingPath;

/**
 A list of test artifcats filename globs (see https://en.wikipedia.org/wiki/Glob_(programming) ) that
 any files in app's container folder matching them will be copied out to a temporary path before
 simulator is cleaned up.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *testArtifactsFilenameGlobs;

/**
 The Designated Initializer.
 */
+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout runnerAppPath:(NSString *)runnerAppPath testTargetAppPath:(nullable NSString *)testTargetAppPath testFilters:(NSArray<NSString *> *)testFilters videoRecordingPath:(nullable NSString *)videoRecordingPath testArtifactsFilenameGlobs:(nullable NSArray<NSString *> *)testArtifactsFilenameGlobs osLogPath:(nullable NSString *)osLogPath additionalApplicationPaths:(NSArray<NSString *> *)additionalApplicationPaths runnerAppLogPath:(nullable NSString *)runnerAppLogPath applicationLogPath:(nullable NSString *)applicationLogPath;

@end

typedef NS_OPTIONS(NSUInteger, FBLogicTestMirrorLogs) {
    /* Does not mirror logs */
    FBLogicTestMirrorNoLogs = 0,
    /* Mirrors logs to files */
    FBLogicTestMirrorFileLogs = 1 << 0,
    /* Mirrors logs to logger */
    FBLogicTestMirrorLogger = 1 << 1,
};

/**
 A Test Configuration, specialized to the running of Logic Tests.
 */
@interface FBLogicTestConfiguration : FBXCTestConfiguration

/**
 The Filters for Logic Tests.
 */
@property (nonatomic, copy, nullable, readonly) NSArray<NSString *> *testFilters;

/**
 How the logic test logs will be mirrored
 */
@property (nonatomic, readonly) FBLogicTestMirrorLogs mirroring;

/**
 The Designated Initializer.
 */
+ (instancetype)configurationWithShims:(FBXCTestShimConfiguration *)shims environment:(NSDictionary<NSString *, NSString *> *)environment workingDirectory:(NSString *)workingDirectory testBundlePath:(NSString *)testBundlePath waitForDebugger:(BOOL)waitForDebugger timeout:(NSTimeInterval)timeout testFilters:(nullable NSArray<NSString *> *)testFilters mirroring:(FBLogicTestMirrorLogs)mirroring;

@end

NS_ASSUME_NONNULL_END
