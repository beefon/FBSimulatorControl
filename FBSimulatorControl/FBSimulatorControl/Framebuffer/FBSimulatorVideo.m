/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSimulatorVideo.h"

#import <objc/runtime.h>

#import <FBControlCore/FBControlCore.h>

#import "FBFramebufferConfiguration.h"
#import "FBSimulatorError.h"
#import "FBVideoEncoderConfiguration.h"
#import "FBVideoEncoderSimulatorKit.h"

@interface FBSimulatorVideo ()

@property (nonatomic, strong, readonly) FBVideoEncoderConfiguration *configuration;
@property (nonatomic, strong, readonly) id<FBControlCoreLogger> logger;
@property (nonatomic, strong, readonly) FBMutableFuture<NSNull *> *completedFuture;

@property (nonatomic, strong, readwrite) FBVideoEncoderSimulatorKit *encoder;

@end

@interface FBSimulatorVideo_SimulatorKit : FBSimulatorVideo

@property (nonatomic, strong, readonly) FBFramebufferSurface *surface;

- (instancetype)initWithConfiguration:(FBVideoEncoderConfiguration *)configuration surface:(FBFramebufferSurface *)surface logger:(id<FBControlCoreLogger>)logger;

@end

@interface FBSimulatorVideo_SimCtl : FBSimulatorVideo

@property (nonatomic, strong, readonly) NSString *deviceSetPath;
@property (nonatomic, strong, readonly) NSString *deviceUUID;
@property (nonatomic, strong, readwrite) FBFuture *recordingTaskFuture;
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

- (instancetype)initWithDeviceSetPath:(NSString *)deviceSetPath deviceUUID:(NSString *)deviceUUID logger:(id<FBControlCoreLogger>)logger;

@end

@implementation FBSimulatorVideo

#pragma mark Initializers

+ (instancetype)videoWithConfiguration:(FBVideoEncoderConfiguration *)configuration surface:(FBFramebufferSurface *)surface logger:(id<FBControlCoreLogger>)logger
{
  return [[FBSimulatorVideo_SimulatorKit alloc] initWithConfiguration:configuration surface:surface logger:logger];
}

+ (instancetype)simctlVideoForDeviceSetPath:(NSString *)deviceSetPath deviceUUID:(NSString *)deviceUUID logger:(id<FBControlCoreLogger>)logger
{
  return [[FBSimulatorVideo_SimCtl alloc] initWithDeviceSetPath:deviceSetPath deviceUUID:deviceUUID logger:logger];
}

- (instancetype)initWithConfiguration:(FBVideoEncoderConfiguration *)configuration logger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _configuration = configuration;
  _logger = logger;
  _completedFuture = [FBMutableFuture future];

  return self;
}

#pragma mark Public Methods

- (FBFuture<FBSimulatorVideo *> *)startRecordingToFile:(nullable NSString *)filePath
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

- (FBFuture<FBSimulatorVideo *> *)stopRecording
{
  NSAssert(NO, @"-[%@ %@] is abstract and should be overridden", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
  return nil;
}

#pragma mark FBiOSTargetContinuation

- (FBiOSTargetFutureType)futureType
{
  return FBiOSTargetFutureTypeVideoRecording;
}

- (FBFuture<NSNull *> *)completed
{
  return [self.completedFuture onQueue:dispatch_get_main_queue() respondToCancellation:^{
    return [self stopRecording];
  }];
}

#pragma mark Private

+ (dispatch_time_t)convertTimeIntervalToDispatchTime:(NSTimeInterval)timeInterval
{
  int64_t timeoutInt = ((int64_t) timeInterval) * ((int64_t) NSEC_PER_SEC);
  return dispatch_time(DISPATCH_TIME_NOW, timeoutInt);
}

@end

@implementation FBSimulatorVideo_SimulatorKit

- (instancetype)initWithConfiguration:(FBVideoEncoderConfiguration *)configuration surface:(FBFramebufferSurface *)surface logger:(id<FBControlCoreLogger>)logger
{
  self = [super initWithConfiguration:configuration logger:logger];
  if (!self) {
    return nil;
  }

  _surface = surface;

  BOOL pendingStart = (configuration.options & FBVideoEncoderOptionsAutorecord) == FBVideoEncoderOptionsAutorecord;
  if (pendingStart) {
    [self startRecordingToFile:nil];
  }

  return self;
}

#pragma mark Public

- (FBFuture<NSNull *> *)startRecordingToFile:(NSString *)filePath
{
  if (self.encoder) {
    return [[FBSimulatorError
      describe:@"Cannot Start Recording, there is already an active encoder"]
      failFuture];
  }
  // Choose the Path for the Log
  NSString *path = filePath ?: self.configuration.filePath;

  // Create and start the encoder.
  self.encoder = [FBVideoEncoderSimulatorKit encoderWithRenderable:self.surface videoPath:path logger:self.logger];
  FBFuture<NSNull *> *future = [self.encoder startRecording];

  return future;
}

- (FBFuture<NSNull *> *)stopRecording
{
  if (!self.encoder) {
    return [[FBSimulatorError
      describe:@"Cannot Stop Recording, there is no active encoder"]
      failFuture];
  }

  // Stop and release the encoder
  FBFuture *future = [self.encoder stopRecording];
  dispatch_queue_t queue = [self.encoder mediaQueue];
  self.encoder = nil;
  return [future onQueue:queue notifyOfCompletion:^(id _) {
    [self.completedFuture resolveWithResult:NSNull.null];
  }];
}

@end

@implementation FBSimulatorVideo_SimCtl

- (instancetype)initWithDeviceSetPath:(NSString *)deviceSetPath deviceUUID:(NSString *)deviceUUID logger:(id<FBControlCoreLogger>)logger
{
  self = [super initWithConfiguration:FBVideoEncoderConfiguration.defaultConfiguration logger:logger];
  if (!self) {
    return nil;
  }

  _deviceSetPath = deviceSetPath;
  _deviceUUID = deviceUUID;
  _queue = dispatch_queue_create("com.facebook.simulatorvideo.simctl", DISPATCH_QUEUE_SERIAL);
  _recordingTaskFuture = nil;

  return self;
}

#pragma mark Public

- (FBFuture<NSNull *> *)startRecordingToFile:(NSString *)filePath
{
  if (self.recordingTaskFuture != nil) {
    return [[FBSimulatorError
      describe:@"Cannot Start Recording, there is already an recording task running"]
      failFuture];
  }
  // Choose the Path for the Log
  filePath = filePath ?: self.configuration.filePath;

  // Make a logger for the output
  id<FBControlCoreLogger> logger = [self.logger withName:@"simctl_encode"];

  // Start the recording task
  self.recordingTaskFuture = [[[[FBTaskBuilder
    withLaunchPath:@"/usr/bin/xcrun"
    arguments:@[
      @"simctl",
      @"--set",
      _deviceSetPath,
      @"io",
      _deviceUUID,
      @"recordVideo",
      @"--type=mp4",
      filePath,
    ]]
    withStdOutToLogger:logger]
    withStdErrToLogger:logger]
    start];

  return self.recordingTaskFuture;
}

- (FBFuture<NSNull *> *)stopRecording
{
  if (self.recordingTaskFuture == nil) {
    return [[FBSimulatorError
      describe:@"Cannot Stop Recording, there is no recording task running"]
      failFuture];
  }

  FBFuture *future = [self.recordingTaskFuture
    onQueue:_queue fmap:^(FBTask *task){
      return [task sendSignal:SIGINT];
    }];
  [self.completedFuture resolveFromFuture:future];

  self.recordingTaskFuture = nil;
  return future;
}

@end
