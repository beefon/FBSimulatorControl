/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSocketServer.h"

#import "FBControlCoreError.h"

@interface FBSocketServer ()

@property (nonatomic, strong, readonly) id<FBSocketServerDelegate> delegate;

@property (nonatomic, strong, readwrite) NSFileHandle *socketHandle;
@property (nonatomic, strong, readwrite) dispatch_source_t acceptSource;

@end

@implementation FBSocketServer

#pragma mark Initializers

+ (instancetype)socketServerOnPort:(in_port_t)port delegate:(id<FBSocketServerDelegate>)delegate
{
  return [[self alloc] initWithPort:port delegate:delegate];
}

- (instancetype)initWithPort:(in_port_t)port delegate:(id<FBSocketServerDelegate>)delegate
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _port = port;
  _delegate = delegate;

  return self;
}

#pragma mark Public

- (FBFuture<NSNull *> *)startListening
{
  if (self.acceptSource) {
    return [[FBControlCoreError
      describe:@"Cannot start listening, socket is already listening"]
      failFuture];
  }
  return [self createSocketWithPort:self.port];
}

- (FBFuture<NSNull *> *)stopListening
{
  if (!self.acceptSource) {
    return [[FBControlCoreError
      describe:@"Cannot stop listening, there is no active socket"]
      failFuture];
  }
  dispatch_source_cancel(self.acceptSource);
  self.acceptSource = nil;
  [self.socketHandle closeFile];
  self.socketHandle = nil;
  return [FBFuture futureWithResult:NSNull.null];
}

- (FBFutureContext<NSNull *> *)startListeningContext
{
  return [[self
    startListening]
    onQueue:self.delegate.queue contextualTeardown:^(NSNull *_, FBFutureState __) {
      [self stopListening];
    }];
}

#pragma mark Private

- (FBFuture<NSNull *> *)createSocketWithPort:(in_port_t)port
{
  // Get the Socket, set some options
  int socketHandle = socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP);
  if (socket <= 0) {
    return [[FBControlCoreError
      describeFormat:@"Failed to create a socket with error '%s'", strerror(errno)]
      failFuture];
  }
  int flagTrue = 1;
  setsockopt(socketHandle, SOL_SOCKET, SO_REUSEADDR, &flagTrue, sizeof(flagTrue));

  // Bind the Socket.
  struct sockaddr_in6 address;
  memset(&address, 0, sizeof(address));
  address.sin6_len = sizeof(address);
  address.sin6_family = AF_INET6;
  address.sin6_port = htons(self.port);
  address.sin6_addr = in6addr_any;
  int result = bind(socketHandle, (struct sockaddr *)&address, sizeof(address));
  if (result != 0) {
    return [[FBControlCoreError
      describeFormat:@"Failed to bind the socket with error '%s'", strerror(errno)]
      failFuture];
  }

  // Start Listening
  result = listen(socketHandle, 10);
  if (result != 0) {
    return [[FBControlCoreError
      describeFormat:@"Failed to listen on the socket error '%s'", strerror(errno)]
      failFuture];
  }

  // Prepare the Accept Source.
  // Since the Client Queue may be concurrent, we should construct a serial queue to serialize the accept() calls
  // The accept() will update internal state so calls *must* be serialized.
  dispatch_queue_t clientQueue = self.delegate.queue;
  NSString *acceptQueueName = [NSString stringWithFormat:@"%s.accept", dispatch_queue_get_label(clientQueue)];
  dispatch_queue_t acceptQueue = dispatch_queue_create(acceptQueueName.UTF8String, DISPATCH_QUEUE_SERIAL);
  self.acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t) socketHandle, 0, acceptQueue);
  __weak typeof(self) weakSelf = self;

  // Dispatch read events from the accept source.
  dispatch_source_set_event_handler(self.acceptSource, ^{
    [weakSelf accept:socketHandle clientQueue:clientQueue error:nil];
  });
  dispatch_source_set_cancel_handler(self.acceptSource, ^{
    close(socketHandle);
  });
  // Start reading socket.
  self.socketHandle = [[NSFileHandle alloc] initWithFileDescriptor:socketHandle closeOnDealloc:YES];
  dispatch_resume(self.acceptSource);

  // Update port
  memset(&address, 0, sizeof(address));
  socklen_t addresslen = sizeof(address);
  getsockname(socketHandle, (struct sockaddr*)(&address), &addresslen);
  _port = ntohs(address.sin6_port);

  return [FBFuture futureWithResult:NSNull.null];
}

- (BOOL)accept:(int)socketHandle clientQueue:(dispatch_queue_t)clientQueue error:(NSError **)error
{
  // Accept the Connnection.
  struct sockaddr_in6 address;
  socklen_t addressLength = sizeof(address);
  int acceptHandle = accept(socketHandle, (struct sockaddr *) &address, &addressLength);
  if (!acceptHandle) {
    return [[FBControlCoreError
      describeFormat:@"accept() failed with error '%s'", strerror(errno)]
      failBool:error];
  }

  // Notify the Delegate the queue it wished to be notified on.
  dispatch_async(clientQueue, ^{
    NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:acceptHandle closeOnDealloc:YES];
    [self.delegate socketServer:self clientConnected:address.sin6_addr handle:fileHandle];
  });
  return YES;
}

@end
