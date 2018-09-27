/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBiOSTargetCommandForwarder.h"

#import <FBControlCore/FBControlCore.h>

#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

@interface FBiOSTargetCommandForwarder ()

@property (nonatomic, weak, readonly) id<FBiOSTarget> target;
@property (nonatomic, copy, readonly) NSArray<Class> *commandClasses;
@property (nonatomic, strong, readonly) NSSet<Class> *statefulCommands; // Stateful command objects that need to be memoized.

@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, id> *memoizedCommands;

@end

@implementation FBiOSTargetCommandForwarder

#pragma mark Initializers

+ (instancetype)forwarderWithTarget:(id<FBiOSTarget>)target commandClasses:(NSArray<Class> *)commandClasses statefulCommands:(NSSet<Class> *)statefulCommands
{
  return [[self alloc] initWithTarget:target commandClasses:commandClasses statefulCommands:statefulCommands];
}

- (instancetype)initWithTarget:(id<FBiOSTarget>)target commandClasses:(NSArray<Class> *)commandClasses statefulCommands:(NSSet<Class> *)statefulCommands

{
  self = [super init];
  if (!self) {
    return nil;
  }

  _target = target;
  _commandClasses = commandClasses;
  _statefulCommands = statefulCommands;
  _memoizedCommands = [NSMutableDictionary dictionary];

  return self;
}

#pragma mark Forwarding

- (id)forwardingTargetForSelector:(SEL)selector
{
  for (Class class in self.commandClasses) {
    if (![class instancesRespondToSelector:selector]) {
      continue;
    }
    return [self obtainCommandForClass:class];
  }
  return [super forwardingTargetForSelector:selector];
}

- (id)obtainCommandForClass:(Class)class
{
  NSString *key = NSStringFromClass(class);
  if (self.memoizedCommands[key]){
    return self.memoizedCommands[key];
  }

  id instance = [self createCommandForClass:class];
  if ([self.statefulCommands containsObject:class]) {
    self.memoizedCommands[key] = instance;
  }
  return instance;
}

- (id)createCommandForClass:(id)class
{
  NSParameterAssert([class conformsToProtocol:@protocol(FBiOSTargetCommand)]);
  return [class commandsWithTarget:self.target];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
  if ([super conformsToProtocol:protocol]) {
    return YES;
  }
  for (Class class in self.commandClasses) {
    id command = [self obtainCommandForClass:class];
    if ([command conformsToProtocol:protocol]) {
      return YES;
    }
  }
  return NO;
}

@end

#pragma clang diagnostic pop
