/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <FBControlCore/FBControlCore.h>

@interface FBProcessStreamTests : XCTestCase

@end

@implementation FBProcessStreamTests

- (void)testClosingActiveStreamStopsWriting
{
  id<FBConsumableLineBuffer> consumer = [FBLineBuffer consumableBuffer];

  FBProcessOutput *output = [FBProcessOutput outputForFileConsumer:consumer];
  NSError *error = nil;
  NSPipe *pipe = [[output attachToPipeOrFileHandle] await:&error];
  XCTAssertNil(error);
  XCTAssertTrue([pipe isKindOfClass:NSPipe.class]);

  [pipe.fileHandleForWriting writeData:[@"HELLO WORLD\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [pipe.fileHandleForWriting writeData:[@"HELLO AGAIN"  dataUsingEncoding:NSUTF8StringEncoding]];

  [[output detach] await:&error];
  XCTAssertNil(error);

  XCTAssertThrows(pipe.fileHandleForWriting.fileDescriptor);
  XCTAssertTrue(consumer.eofHasBeenReceived.hasCompleted);
}

- (void)testViaFifo
{
  id<FBAccumulatingLineBuffer> buffer = [FBLineBuffer accumulatingBuffer];
  NSError *error = nil;
  id<FBProcessFileOutput> output = [[[FBProcessOutput outputForFileConsumer:buffer] providedThroughFile] await:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(output);

  // Start Reading Asyncly so that the fifo is opened, it can then be written to.
  FBFuture *startReading = [output startReading];
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:output.filePath];
  BOOL success = [startReading await:&error] != nil;
  XCTAssertNil(error);
  XCTAssertTrue(success);

  [fileHandle writeData:[@"HELLO WORLD\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [fileHandle writeData:[@"HELLO AGAIN" dataUsingEncoding:NSUTF8StringEncoding]];
  [fileHandle closeFile];

  success = [buffer.eofHasBeenReceived await:&error] != nil;
  XCTAssertNil(error);
  XCTAssertTrue(success);

  NSArray<NSString *> *expected = @[@"HELLO WORLD", @"HELLO AGAIN"];
  XCTAssertEqualObjects(buffer.lines, expected);
}

- (void)testFileToFileDoesNotInvolveIndirection
{
  NSString *filePath = @"/tmp/hello_world.txt";
  NSError *error = nil;
  id<FBProcessFileOutput> output = [[[FBProcessOutput outputForFilePath:filePath] providedThroughFile] await:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(output);

  XCTAssertEqualObjects(filePath, output.filePath);
}

- (void)testConcurrentAttachmentIsProhibited
{
  id<FBConsumableLineBuffer> consumer = [FBLineBuffer consumableBuffer];
  FBProcessOutput *output = [FBProcessOutput outputForFileConsumer:consumer];

  dispatch_queue_t concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
  dispatch_group_t group = dispatch_group_create();
  __block FBFuture<id> *firstAttempt = nil;
  __block FBFuture<NSFileHandle *> *secondAttempt = nil;
  __block FBFuture<id> *thirdAttempt = nil;

  dispatch_group_async(group, concurrentQueue, ^{
    firstAttempt = [output attachToPipeOrFileHandle];
  });
  dispatch_group_async(group, concurrentQueue, ^{
    secondAttempt = [output attachToFileHandle];
  });
  dispatch_group_async(group, concurrentQueue, ^{
    thirdAttempt = [output attachToPipeOrFileHandle];
  });
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  [firstAttempt await:nil];
  [secondAttempt await:nil];
  [thirdAttempt await:nil];

  NSUInteger successes = 0;
  if (firstAttempt.state == FBFutureStateDone) {
    successes++;
  }
  if (secondAttempt.state == FBFutureStateDone) {
    successes++;
  }
  if (thirdAttempt.state == FBFutureStateDone) {
    successes++;
  }

  NSError *error;
  [[output detach] await:&error];
  XCTAssertNil(error);
  XCTAssertEqual(successes, 1u);
}

@end
