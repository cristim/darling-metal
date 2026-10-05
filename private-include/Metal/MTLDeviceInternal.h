// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEVICEINTERNAL_H_
#define _METAL_MTLDEVICEINTERNAL_H_

#import <Metal/MTLDevice.h>

#if DARLING_METAL_ENABLED
#include <indium/indium.hpp>
#endif

void MTLDeviceDestroyAll(void);

@interface MTLDeviceInternal : NSObject <MTLDevice>

#if DARLING_METAL_ENABLED
@property(readonly) std::shared_ptr<Indium::Device> device;

- (instancetype)initWithDevice: (std::shared_ptr<Indium::Device>)device;

- (void)stopPolling;

- (void)waitUntilPollingIsStopped;

// Implicit queue backing -[MTLDevice newCommandBuffer]. Metal apps call that
// before every frame and rarely ever ask for an explicit queue.
- (id<MTLCommandQueue>)implicitCommandQueue;
#endif

@end

#endif // _METAL_MTLDEVICEINTERNAL_H_
