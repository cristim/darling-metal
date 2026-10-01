// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLCOMMANDQUEUE_H_
#define _METAL_MTLCOMMANDQUEUE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLDevice;
@protocol MTLCommandBuffer;
@protocol MTLCommandQueue;

@protocol MTLCommandQueue <NSObject>

@property(readonly) id<MTLDevice> device;
@property(nullable, copy, atomic) NSString* label;

- (id<MTLCommandBuffer>)commandBuffer;

/*! -[MTLDevice newCommandQueueWithMaxCommandBufferCount:] is not declared.
 Apple describes it as a command queue with "a given upper bound on
 non-completed command buffers", which is a limit on how many submissions may be
 in flight on the queue. indium's CommandQueue has no such bound and no place to
 put one: command buffers are created from the queue and submitted independently,
 and Vulkan states no equivalent limit, so the count could not be honoured even
 as a stored number. Passing it through and ignoring it would leave a caller
 believing it had bounded its submissions when it had not, which is how a
 pipeline ends up waiting on a queue that was never going to signal.
 -newCommandQueue is declared and returns a real queue; Apple documents it as
 allowing 64 non-completed command buffers, which this framework does not
 enforce and so does not claim to. */

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLCOMMANDQUEUE_H_
