/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBXCTestKitFixtures.h"

#import <FBSimulatorControl/FBSimulatorControl.h>

@implementation FBXCTestKitFixtures

+ (NSString *)createTemporaryDirectory
{
  NSError *error;
  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSString *temporaryDirectory =
      [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  [fileManager createDirectoryAtPath:temporaryDirectory withIntermediateDirectories:YES attributes:nil error:&error];
  NSAssert(!error, @"Could not create temporary directory");

  return temporaryDirectory;
}

+ (NSString *)tableSearchApplicationPath
{
  return [[[NSBundle bundleForClass:self] pathForResource:@"TableSearch" ofType:@"app"]
      stringByAppendingPathComponent:@"TableSearch"];
}

+ (NSString *)simpleTestTargetPath
{
  return [[NSBundle bundleForClass:self] pathForResource:@"SimpleTestTarget" ofType:@"xctest"];
}

@end
