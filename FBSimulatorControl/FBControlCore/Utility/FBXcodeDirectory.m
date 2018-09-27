/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXcodeDirectory.h"

#import "FBTask.h"
#import "FBTaskBuilder.h"
#import "FBControlCoreError.h"
#import "FBControlCoreGlobalConfiguration.h"

@implementation FBXcodeDirectory

#pragma mark Initializers

+ (NSString *)xcodeSelectFromCommandLine
{
  return [self new];
}

#pragma mark Public Methods

- (FBFuture<NSString *> *)xcodePath
{
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  return [[[FBTaskBuilder
    withLaunchPath:@"/usr/bin/xcode-select" arguments:@[@"--print-path"]]
    runUntilCompletion]
    onQueue:queue fmap:^(FBTask *task) {
      NSString *directory = [task stdOut];
      if (!directory) {
        return [[FBControlCoreError
          describeFormat:@"Xcode Path could not be determined from `xcode-select`: %@", directory]
          failFuture];
      }
      directory = [directory stringByResolvingSymlinksInPath];

      if ([directory stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length == 0) {
        return [[FBControlCoreError
          describe:@"No Xcode Directory returned from xcode-select. Run xcode-select(1) to set this to a valid Xcode install."]
          failFuture];
      }
      if (![NSFileManager.defaultManager fileExistsAtPath:directory]) {
        return [[FBControlCoreError
          describeFormat:@"No Xcode Directory at: %@", directory]
          failFuture];
      }
      if ([directory isEqualToString:@"/"] ) {
        return [[FBControlCoreError
          describe:@"Xcode Directory is defined as the Root Filesystem. Run xcode-select(1) to set this to a valid Xcode install."]
          failFuture];
      }
      return [FBFuture futureWithResult:directory];
    }];
}

@end
