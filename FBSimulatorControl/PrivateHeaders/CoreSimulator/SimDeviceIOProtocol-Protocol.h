/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class NSArray, NSObject, NSUUID;
@protocol SimDeviceIOPortConsumer, SimDeviceIOPortInterface;

@protocol SimDeviceIOProtocol <NSObject>

- (NSArray<id<SimDeviceIOPortInterface>> *)ioPorts;
- (id<SimDeviceIOPortInterface>)ioPortForUUID:(NSUUID *)arg1;

@optional

/**
 Removed in Xcode 9.0
 */
- (void)attachConsumer:(id)arg1 toPort:(id)arg2;

/**
 Removed in Xcode 10.0
 */
- (void)detachConsumer:(NSObject<SimDeviceIOPortConsumer> *)arg1 fromPort:(NSObject<SimDeviceIOPortInterface> *)arg2;
- (void)attachConsumer:(NSObject<SimDeviceIOPortConsumer> *)arg1 withUUID:(id)arg2 toPort:(NSObject<SimDeviceIOPortInterface> *)arg3 errorQueue:(dispatch_queue_t)arg4 errorHandler:(id)arg5;


@end
