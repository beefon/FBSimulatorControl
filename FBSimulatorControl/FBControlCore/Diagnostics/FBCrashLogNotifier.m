/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCrashLogNotifier.h"

#import "FBCrashLogInfo.h"
#import "FBCrashLogStore.h"
#import "FBControlCoreGlobalConfiguration.h"
#import "FBControlCoreLogger.h"
#import "FBControlCoreError.h"

@interface FBCrashLogNotifier ()

@property (nonatomic, copy, readwrite) NSDate *sinceDate;

@end

@implementation FBCrashLogNotifier

#pragma mark Initializers

- (instancetype)initWithLogger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _store = [FBCrashLogStore storeForDirectories:FBCrashLogInfo.diagnosticReportsPaths logger:logger];

  _sinceDate = NSDate.date;

  return self;
}

+ (instancetype)sharedInstance
{
  static dispatch_once_t onceToken;
  static FBCrashLogNotifier *notifier;
  dispatch_once(&onceToken, ^{
    notifier = [[FBCrashLogNotifier alloc] initWithLogger:FBControlCoreGlobalConfiguration.defaultLogger];
  });
  return notifier;
}

#pragma mark Public Methods

- (instancetype)startListening:(BOOL)onlyNew
{
  self.sinceDate = NSDate.date;
    
  return self;
}

- (FBFuture<FBCrashLogInfo *> *)nextCrashLogForPredicate:(NSPredicate *)predicate
{
  [self startListening:YES];

  dispatch_queue_t queue = dispatch_queue_create("com.facebook.fbcontrolcore.crashlogfetch", DISPATCH_QUEUE_SERIAL);
  return [FBFuture
   onQueue:queue resolveUntil:^{
     FBCrashLogInfo *crashInfo = [[[FBCrashLogInfo
       crashInfoAfterDate:FBCrashLogNotifier.sharedInstance.sinceDate]
       filteredArrayUsingPredicate:predicate]
       firstObject];
     if (!crashInfo) {
       return [[[FBControlCoreError
         describeFormat:@"Crash Log Info for %@ could not be obtained", predicate]
         noLogging]
         failFuture];
     }
     return [FBFuture futureWithResult:crashInfo];
   }];
}

@end
