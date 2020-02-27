/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBSimulatorControl/FBSimulatorControl.h>

#import "FBSimulatorControlAssertions.h"
#import "FBSimulatorControlFixtures.h"
#import "FBSimulatorControlTestCase.h"

@interface FBSimulatorApplicationCommandsTests : FBSimulatorControlTestCase

@end

@implementation FBSimulatorApplicationCommandsTests

- (void)testApplicationIsInstalledWithoutLibswiftCoreDylibOnNewerOsVersions
{
  if (FBSimulatorControlTestCase.isRunningOnTravis) {
    return;
  }
  
  XCTAssertFalse([self libswiftcoreExistsInInstalledApplicationForDevice:FBDeviceModeliPhone11ProMax os:FBOSVersionNameiOS_13_2]);
}

- (void)testApplicationIsInstalledWithLibswiftCoreDylibOnOlderOsVersions
{
  if (FBSimulatorControlTestCase.isRunningOnTravis) {
    return;
  }
  
  XCTAssertTrue([self libswiftcoreExistsInInstalledApplicationForDevice:FBDeviceModeliPhoneSE os:FBOSVersionNameiOS_10_3]);
}

- (BOOL)libswiftcoreExistsInInstalledApplicationForDevice:(FBDeviceModel)device os:(FBOSVersionName)os {
  FBSimulatorConfiguration *simulatorConfiguration = [[FBSimulatorConfiguration.defaultConfiguration
                                                      withOSNamed:os]
                                                      withDeviceModel:device];
  
  FBSimulator *simulator = [self assertObtainsBootedSimulatorWithConfiguration:simulatorConfiguration bootConfiguration:self.bootConfiguration];
  
  FBApplicationBundle *application = self.swiftAppWithUnitTestsApplication;
  NSError *error = nil;
  BOOL success = [[simulator installApplicationWithPath:application.path] await:&error] != nil;
  XCTAssertNil(error);
  XCTAssertTrue(success);
  FBInstalledApplication *installedApplication = [simulator installedApplicationWithBundleID:application.bundleID].result;
  
  NSString *libswiftCorePath = [installedApplication.bundle.path stringByAppendingPathComponent:@"Frameworks/libswiftCore.dylib"];
  BOOL libswiftCoreExists = [[NSFileManager defaultManager] fileExistsAtPath:libswiftCorePath];
  
  return libswiftCoreExists;
}

@end
