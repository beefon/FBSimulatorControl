/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestBootstrapper.h"

#import <FBControlCore/FBControlCore.h>
#import <XCTestBootstrap/XCTestBootstrap.h>

#import <FBXCTestKit/FBXCTestKit.h>

@interface FBXCTestBootstrapper ()

@property (nonatomic, strong, readonly) FBXCTestLogger *logger;

@end

@implementation FBXCTestBootstrapper

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _logger = FBXCTestLogger.defaultLoggerInDefaultDirectory;
  FBControlCoreGlobalConfiguration.defaultLogger = _logger;
  FBControlCoreGlobalConfiguration.debugLoggingEnabled = YES;

  return self;
}

- (BOOL)bootstrap
{
  NSError *error;
  NSString *workingDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSProcessInfo.processInfo.globallyUniqueString];

  if (![NSFileManager.defaultManager createDirectoryAtPath:workingDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
    return [self printErrorMessage:error];
  }

  NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
  arguments = [arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)];
  [self.logger.debug logFormat:@"fbxctest arguments: %@", [FBCollectionInformation oneLineDescriptionFromArray:arguments]];
  [self.logger.debug logFormat:@"xcode configuration: %@", [FBCollectionInformation oneLineDescriptionFromDictionary:FBXcodeConfiguration.new.jsonSerializableRepresentation]];
  FBXCTestCommandLine *commandLine = [FBXCTestCommandLine
    commandLineFromArguments:arguments
    processUnderTestEnvironment:@{}
    workingDirectory:workingDirectory
    error:&error];
  if (!commandLine) {
    return [self printErrorMessage:error];
  }
  FBFileWriter *stdOutFileWriter = [FBFileWriter syncWriterWithFileHandle:NSFileHandle.fileHandleWithStandardOutput];
  FBJSONTestReporter *reporter = [[FBJSONTestReporter alloc] initWithTestBundlePath:commandLine.configuration.testBundlePath testType:commandLine.configuration.testType logger:self.logger fileConsumer:stdOutFileWriter];
  FBXCTestContext *context = [FBXCTestContext contextWithReporter:reporter logger:self.logger];

  [self.logger.info logFormat:@"Bootstrapping Test Runner with Configuration %@", [FBCollectionInformation oneLineJSONDescription:commandLine.configuration]];
  FBXCTestBaseRunner *testRunner = [FBXCTestBaseRunner testRunnerWithCommandLine:commandLine context:context];
  if (![[testRunner execute] await:&error]) {
    return [self printErrorMessage:error];
  }

  if (![NSFileManager.defaultManager removeItemAtPath:workingDirectory error:&error]) {
    return [self printErrorMessage:error];
  }

  return YES;
}


- (BOOL)printErrorMessage:(NSError *)error
{
  NSString *message = error.localizedDescription;
  if (message) {
    fputs(message.UTF8String, stderr);
  }
  fflush(stderr);
  return NO;
}

@end
