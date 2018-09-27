/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBSimulatorControl/FBFramebufferSurface.h>

NS_ASSUME_NONNULL_BEGIN

@class FBFramebufferSurface;
@protocol FBSimulatorEventSink;

/**
 Provides access to an Image Representation of a Simulator's Framebuffer.
 */
@interface FBSimulatorImage : NSObject

#pragma mark Initializers

/**
 Creates a new FBSimulatorImage instance using a Surface.

 @param surface the surface to obtain frames from.
 @param logger the logger to use.
 @return a new FBSimulatorImage instance.
 */
+ (instancetype)imageWithSurface:(FBFramebufferSurface *)surface logger:(nullable id<FBControlCoreLogger>)logger;

#pragma mark Public Methods

/**
 The Latest Image from the Framebuffer.
 This will return an autorelease Image, so it should be retained by the caller.
 */
- (nullable CGImageRef)image;

/**
 Get a JPEG encoded representation of the Image.

 @param error an error out for any error that occurs.
 @return the data if successful, nil otherwise.
 */
- (nullable NSData *)jpegImageDataWithError:(NSError **)error;

/**
 Get a PNG encoded representation of the Image.

 @param error an error out for any error that occurs.
 @return the data if successful, nil otherwise.
 */
- (nullable NSData *)pngImageDataWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
