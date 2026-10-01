// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#ifndef _METAL_MTLDEVICE_H_
#define _METAL_MTLDEVICE_H_

#import <Foundation/Foundation.h>

#import <Metal/MTLResource.h>
#import <Metal/MTLDefines.h>

METAL_DECLARATIONS_BEGIN

@protocol MTLComputePipelineState;
@protocol MTLFunction;
@protocol MTLCommandQueue;
@protocol MTLDevice;
@protocol MTLBuffer;
@protocol MTLLibrary;
@protocol MTLRenderPipelineState;
@protocol MTLTexture;
@protocol MTLDepthStencilState;
@protocol MTLSamplerState;

@class MTLCompileOptions;
@class MTLComputePipelineDescriptor;
@class MTLAutoreleasedComputePipelineReflection;
@class MTLDepthStencilDescriptor;
@class MTLRenderPipelineDescriptor;
@class MTLSamplerDescriptor;
@class MTLTextureDescriptor;

typedef NS_OPTIONS(NSUInteger, MTLPipelineOption) {
	MTLPipelineOptionNone = 0,
	MTLPipelineOptionArgumentInfo = 1 << 0,
	MTLPipelineOptionBufferTypeInfo = 1 << 1,
	MTLPipelineOptionFailOnBinaryArchiveMiss = 1 << 2,
};

typedef NSString* MTLDeviceNotificationName;
typedef void (^MTLDeviceNotificationHandler)(id<MTLDevice> device, MTLDeviceNotificationName notifyName);

MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification;
MTL_EXPORT MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification;

MTL_EXPORT id<MTLDevice> MTLCreateSystemDefaultDevice(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevices(void);
MTL_EXPORT NSArray<id<MTLDevice>>* MTLCopyAllDevicesWithObserver(id<NSObject>* observer, MTLDeviceNotificationHandler handler);
MTL_EXPORT void MTLRemoveDeviceObserver(id<NSObject> observer);

@protocol MTLDevice <NSObject>

/*!
 @property recommendedMaxWorkingSetSize
 @abstract An approximation of how much memory this device can use with good
 performance. Keeping the total size of all resources and heaps below it avoids
 overcommitting the device and the performance penalty that comes with it. */
@property(nonatomic, readonly) uint64_t recommendedMaxWorkingSetSize;

/*!
 @property name
 @abstract The full name of the vendor device.
 @discussion This is the device's own name, which indium reads out of
 VkPhysicalDeviceProperties::deviceName. That member is specified to be a
 null-terminated UTF-8 string, so it converts without loss and without this
 framework having to guess an encoding. */
@property(nonnull, readonly) NSString* name;

/*! The selectors below are deliberately NOT declared, so a caller that reaches
 for one gets an unrecognised selector naming the gap. Each is a question about
 the hardware that indium cannot answer, and a plausible answer would be worse
 than the error:

 -supportsFamily: and -supportsCounterSampling: ask what the underlying GPU can
 do. MTLGPUFamily is Apple's own numbering of silicon generations (Apple1
 through Apple7, Mac1, Mac2, Common1 through Common3, MacCatalyst1 and 2) and
 Vulkan has no property that maps onto it: deviceName is a free-form string and
 vendorID/deviceID identify the driver, not the GPU family. Returning YES or NO
 would be a claim about real hardware, and on a machine whose GPU genuinely
 supports counter sampling, NO would be a lie that sends the caller down a path
 it did not need to avoid. MTLCounterSamplingPoint likewise enumerates where
 Metal may sample counters, and indium has no query pool at all, so it has no
 sampling point to report on. Neither is declared until indium can say something
 true.

 -minimumLinearTextureAlignmentForPixelFormat: returns the alignment Metal
 requires of a linear texture's offset and rowBytes, per pixel format, and
 throws for depth, stencil and compressed formats. Apple states the requirement
 but not the table, so there is nothing here to derive a value from, and indium
 does not enforce any linear-texture alignment for it to report: its
 replaceRegion: passes bytesPerRow straight through unvalidated. Returning a
 Vulkan limit such as optimalBufferCopyOffsetAlignment would answer a different
 question, since that bounds buffer copies rather than texture layout.

 The remaining omitted selectors are documented where the class that would have
 provided the object is declared: -newEvent in MTLSharedEvent.h,
 -newArgumentEncoderWithArguments: in MTLArgumentDescriptor.h,
 -newCommandQueueWithMaxCommandBufferCount: in MTLCommandQueue.h,
 -newBinaryArchiveWithDescriptor:error: in MTLBinaryArchive.h,
 -newCounterSampleBufferWithDescriptor:error: in MTLCounterSampleBuffer.h, and
 the acceleration-structure selectors in MTLAccelerationStructure.h. */

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                                             options: (MTLPipelineOption)options
                                                          reflection: (MTLAutoreleasedComputePipelineReflection*)reflection
                                                               error: (NSError**)error;

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                             error: (NSError**)error;

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                           options: (MTLPipelineOption)options 
                                                        reflection: (MTLAutoreleasedComputePipelineReflection*)reflection 
                                                             error: (NSError**)error;

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                             error: (NSError**)error;

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor;

- (id<MTLSamplerState>)newSamplerStateWithDescriptor: (MTLSamplerDescriptor*)descriptor;

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor: (MTLDepthStencilDescriptor*)descriptor;

- (id<MTLCommandQueue>)newCommandQueue;

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options;

- (id<MTLBuffer>)newBufferWithBytes: (const void*)pointer
                             length: (NSUInteger)length
                            options: (MTLResourceOptions)options;

- (id<MTLLibrary>)newDefaultLibrary;

- (id<MTLLibrary>)newDefaultLibraryWithBundle: (NSBundle*)bundle
                                        error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithURL: (NSURL*)url
                              error: (NSError**)error;

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error;

- (nullable id<MTLLibrary>)newLibraryWithSource: (NSString*)source
                                        options: (nullable MTLCompileOptions*)options
                                          error: (NSError**)error;

// TODO: other methods and properties

@end

METAL_DECLARATIONS_END

#endif // _METAL_MTLDEVICE_H_
