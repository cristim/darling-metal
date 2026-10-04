// SPDX-FileCopyrightText: 2026 Darling Developers
// SPDX-License-Identifier: MPL-2.0

#import <Metal/MTLDeviceInternal.h>
#import <dispatch/dispatch.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/MTLComputePipelineInternal.h>
#import <Metal/MTLCommandQueueInternal.h>
#import <Metal/MTLBufferInternal.h>
#import <Metal/MTLLibraryInternal.h>
#import <Metal/stubs.h>
#import <Metal/MTLRenderPipelineInternal.h>
#import <Metal/MTLTextureDescriptorInternal.h>
#import <Metal/MTLTextureInternal.h>
#import <Metal/MTLSamplerDescriptorInternal.h>
#import <Metal/MTLSamplerStateInternal.h>
#import <Metal/MTLDepthStencilDescriptorInternal.h>
#import <Metal/MTLMSLReflection.h>

#include <mslc/mslc.h>

#include <stdlib.h>
#include <string.h>

MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasAddedNotification = @"MTLDeviceWasAdded";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceRemovalRequestedNotification = @"MTLDeviceRemovalRequested";
MTL_EXTERN const MTLDeviceNotificationName MTLDeviceWasRemovedNotification = @"MTLDeviceWasRemoved";

#if DARLING_METAL_ENABLED

static NSMutableArray<MTLDeviceInternal*>* devices = nil;
static dispatch_once_t devicesInitToken = 0;
static MTLDeviceInternal* systemDefaultDevice = nil;

static void ensureDevices(void) {
	dispatch_once(&devicesInitToken, ^{
		ensureMetalInitialized();
		devices = [NSMutableArray new];

		// for now, we just have the system default device
		auto indiumDevice = Indium::createSystemDefaultDevice();
		if (indiumDevice) {
			systemDefaultDevice = [[MTLDeviceInternal alloc] initWithDevice: indiumDevice];

			[devices addObject: systemDefaultDevice];
		}
	});
};

void MTLDeviceDestroyAll(void) {
	for (MTLDeviceInternal* device in devices) {
		[device stopPolling];
		[device waitUntilPollingIsStopped];
	}

	if (systemDefaultDevice) {
		[systemDefaultDevice release];
	}

	if (devices) {
		[devices release];
	}
};

#endif

static bool metalDisabledByEnvironment(void) {
	const char* disable = getenv("DARLING_METAL_DISABLE");
	if (disable && disable[0] != '\0' && disable[0] != '0') {
		return true;
	}
	const char* enable = getenv("DARLING_ENABLE_METAL");
	if (enable && (enable[0] == '1' || enable[0] == 'y' || enable[0] == 'Y')) {
		return false;
	}
	// By default, since Metal AIR translation and render pipelines are still under active development
	// (e.g. advanced texture samplers in Iridium), keep Metal gated behind DARLING_ENABLE_METAL=1
	// so SDL2 / OpenGL games automatically fall back to the mature OpenGL renderer.
	return true;
}

MTL_EXTERN
id<MTLDevice> MTLCreateSystemDefaultDevice(void) {
	if (metalDisabledByEnvironment()) {
		return nil;
	}
#if DARLING_METAL_ENABLED
	ensureDevices();
	if (systemDefaultDevice) {
		return [systemDefaultDevice retain];
	}
#endif
	return nil;
};

MTL_EXTERN
NSArray<id<MTLDevice>>* MTLCopyAllDevices(void) {
	if (metalDisabledByEnvironment()) {
		return [NSArray new];
	}
#if DARLING_METAL_ENABLED
	ensureDevices();
	return [devices copy];
#else
	return [NSArray new];
#endif
};

MTL_EXTERN
NSArray<id<MTLDevice>>* MTLCopyAllDevicesWithObserver(id<NSObject>* observer, MTLDeviceNotificationHandler handler) {
	// TODO: actually use observer
	if (observer) {
		*observer = [NSObject new];
	}
	return MTLCopyAllDevices();
};

static NSError* MSLLibraryError(NSString* reason, MTLLibraryError code) {
	return [NSError errorWithDomain: MTLLibraryErrorDomain
	                           code: code
	                       userInfo: @{
		NSLocalizedDescriptionKey: reason,
	}];
}

MTL_EXTERN
void MTLRemoveDeviceObserver(id<NSObject> observer) {
	// TODO: actually use observer
	[observer release];
};

@implementation MTLDeviceInternal

#if DARLING_METAL_ENABLED

{
	NSThread* _pollingThread;
	NSCondition* _threadExitCondition;
	BOOL _threadIsRunning;
}

@synthesize device = _device;

- (void)pollingLoop
{
	[_threadExitCondition lock];
	_threadIsRunning = YES;
	[_threadExitCondition unlock];

	while (!_pollingThread.isCancelled) {
		_device->pollEvents(UINT64_MAX);
	}

	[_threadExitCondition lock];
	_threadIsRunning = NO;
	[_threadExitCondition broadcast];
	[_threadExitCondition unlock];
}

- (instancetype)initWithDevice: (std::shared_ptr<Indium::Device>)device
{
	self = [super init];
	if (self != nil) {
		_device = device;
		_threadExitCondition = [NSCondition new];
		_threadIsRunning = NO;
		_pollingThread = [[NSThread alloc] initWithTarget: self selector: @selector(pollingLoop) object: nil];
		[_pollingThread start];
	}
	return self;
}

- (void)dealloc
{
	[_pollingThread release];
	[_threadExitCondition release];

	[super dealloc];
}

- (void)stopPolling
{
	[_pollingThread cancel];
	_device->wakeupEventLoop();
}

- (void)waitUntilPollingIsStopped
{
	// wait for the polling thread to die
	[_threadExitCondition lock];
	while (_threadIsRunning) {
		[_threadExitCondition wait];
	}
	[_threadExitCondition unlock];
}

- (uint64_t)recommendedMaxWorkingSetSize
{
	// indium decides this from the device's memory budget where the driver
	// reports one and from its memory heap size where it does not. See
	// Indium::PrivateDevice::recommendedMaxWorkingSetSize for why a budget is
	// the honest analogue and why maxMemoryAllocationCount is not.
	return _device->recommendedMaxWorkingSetSize();
}

- (NSString*)name
{
	// VkPhysicalDeviceProperties::deviceName, which the Vulkan specification
	// defines as a null-terminated UTF-8 string, so this is the device's own
	// name in its own encoding and not a guess at one.
	return [NSString stringWithUTF8String: _device->name().c_str()];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor: (MTLComputePipelineDescriptor*)descriptor
                                                             options: (MTLPipelineOption)options
                                                          reflection: (MTLAutoreleasedComputePipelineReflection*)reflection
                                                               error: (NSError**)error
{
	auto pso = _device->newComputePipelineState(descriptor.asIndiumDescriptor, static_cast<Indium::PipelineOption>(options), nullptr);
	if (!pso) {
		if (error) {
			// TODO: better error and/or match what the official Metal method does
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOMEM userInfo: nil];
		}
		return nil;
	}
	return [[MTLComputePipelineStateInternal alloc] initWithState: pso device: self label: descriptor.label];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                             error: (NSError**)error
{
	return [self newComputePipelineStateWithFunction: computeFunction
	                                         options: MTLPipelineOptionNone
	                                      reflection: nil
	                                           error: error];
}

- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction: (id<MTLFunction>)computeFunction 
                                                           options: (MTLPipelineOption)options 
                                                        reflection: (MTLAutoreleasedComputePipelineReflection*)reflection 
                                                             error: (NSError**)error
{
	auto pso = _device->newComputePipelineState(((MTLFunctionInternal*)computeFunction).function, static_cast<Indium::PipelineOption>(options), nullptr);
	if (!pso) {
		if (error) {
			// TODO: better error and/or match what the official Metal method does
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOMEM userInfo: nil];
		}
		return nil;
	}
	return [[MTLComputePipelineStateInternal alloc] initWithState: pso device: self label: nil];
}

- (id<MTLRenderPipelineState>)newRenderPipelineStateWithDescriptor: (MTLRenderPipelineDescriptor*)descriptor
                                                             error: (NSError**)error
{
	if (descriptor == nil || descriptor.vertexFunction == nil) {
		if (error) {
			*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorFunctionNotFound userInfo: nil];
		}
		return nil;
	}
	try {
		auto pso = _device->newRenderPipelineState([descriptor asIndiumDescriptor]);
		if (!pso) {
			if (error) {
				*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorInternal userInfo: nil];
			}
			return nil;
		}
		return [[MTLRenderPipelineStateInternal alloc] initWithState: pso device: self label: descriptor.label];
	} catch (const std::exception& e) {
		if (error) {
			*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorInternal userInfo: @{
				NSLocalizedDescriptionKey: [NSString stringWithUTF8String: e.what()]
			}];
		}
		return nil;
	}
}

- (id<MTLTexture>)newTextureWithDescriptor: (MTLTextureDescriptor*)descriptor
{
	auto texture = _device->newTexture([descriptor asIndiumDescriptor]);
	if (!texture) {
		return nil;
	}
	return [[MTLTextureInternal alloc] initWithTexture: texture device: self resourceOptions: descriptor.resourceOptions];
}

- (id<MTLSamplerState>)newSamplerStateWithDescriptor: (MTLSamplerDescriptor*)descriptor
{
	auto state = _device->newSamplerState([descriptor asIndiumDescriptor]);
	if (!state) {
		return nil;
	}
	MTLSamplerStateInternal* sampler = [[MTLSamplerStateInternal alloc] initWithState: state device: self];
	sampler.label = descriptor.label;
	return sampler;
}

- (id<MTLDepthStencilState>)newDepthStencilStateWithDescriptor: (MTLDepthStencilDescriptor*)descriptor
{
	auto state = _device->newDepthStencilState([descriptor asIndiumDescriptor]);
	if (!state) {
		return nil;
	}
	return [[MTLDepthStencilStateInternal alloc] initWithState: state device: self];
}

- (id<MTLCommandQueue>)newCommandQueue
{
	auto queue = _device->newCommandQueue();
	if (!queue) {
		return nil;
	}
	return [[MTLCommandQueueInternal alloc] initWithQueue: queue device: self];
}

- (id<MTLBuffer>)newBufferWithLength: (NSUInteger)length
                             options: (MTLResourceOptions)options
{
	auto buf = _device->newBuffer(length, static_cast<Indium::ResourceOptions>(options));
	if (!buf) {
		return nil;
	}
	return [[MTLBufferInternal alloc] initWithBuffer: buf device: self resourceOptions: options];
}

- (id<MTLBuffer>)newBufferWithBytes: (const void*)pointer
                             length: (NSUInteger)length
                            options: (MTLResourceOptions)options
{
	auto buf = _device->newBuffer(pointer, length, static_cast<Indium::ResourceOptions>(options));
	if (!buf) {
		return nil;
	}
	return [[MTLBufferInternal alloc] initWithBuffer: buf device: self resourceOptions: options];
}

- (id<MTLLibrary>)newDefaultLibrary
{
	return [self newDefaultLibraryWithBundle: [NSBundle mainBundle] error: nil];
}

- (id<MTLLibrary>)newDefaultLibraryWithBundle: (NSBundle*)bundle
                                        error: (NSError**)error
{
	NSURL* url = [bundle URLForResource: @"default" withExtension: @"metallib"];
	if (url == nil) {
		if (error) {
			// TODO: better error
			*error = [NSError errorWithDomain: NSPOSIXErrorDomain code: ENOENT userInfo: nil];
		}
		return nil;
	}
	return [self newLibraryWithURL: url error: error];
}

- (id<MTLLibrary>)newLibraryWithURL: (NSURL*)url
                              error: (NSError**)error
{
	NSData* data = [NSData dataWithContentsOfURL: url options: 0 error: error];
	if (data == nil) {
		// error was already written
		return nil;
	}
	auto lib = _device->newLibrary(data.bytes, data.length);
	if (!lib) {
		return nil;
	}
	return [[MTLLibraryInternal alloc] initWithLibrary: lib device: self];
}

- (id<MTLLibrary>)newLibraryWithData: (dispatch_data_t)data
                               error: (NSError**)error
{
	NSData* nsdata = (NSData*)data;
	if (nsdata == nil || [nsdata length] == 0) {
		if (error) {
			*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorCompileFailure userInfo: nil];
		}
		return nil;
	}
	try {
		auto lib = _device->newLibrary(nsdata.bytes, nsdata.length);
		if (!lib) {
			if (error) {
				*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorCompileFailure userInfo: nil];
			}
			return nil;
		}
		return [[MTLLibraryInternal alloc] initWithLibrary: lib device: self];
	} catch (const std::exception& e) {
		if (error) {
			*error = [NSError errorWithDomain: MTLLibraryErrorDomain code: MTLLibraryErrorCompileFailure userInfo: @{
				NSLocalizedDescriptionKey: [NSString stringWithUTF8String: e.what()]
			}];
		}
		return nil;
	}
}

- (id<MTLLibrary>)newLibraryWithSource: (NSString*)source
                               options: (MTLCompileOptions*)options
                                 error: (NSError**)error
{
	if (source == nil) {
		if (error) {
			*error = MSLLibraryError(@"there is no source to compile",
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	// mslc takes the source as bytes rather than as a string, and takes the length
	// explicitly, so the encoding has to be decided here rather than inferred. A
	// string that is not representable in UTF-8 is refused instead of being
	// silently truncated at the first byte that is not part of a character, which
	// would compile to a module from a source nobody wrote.
	NSData* utf8 = [source dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: NO];
	if (utf8 == nil) {
		if (error) {
			*error = MSLLibraryError(@"the source is not representable in UTF-8",
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	MslcOptions mslcOptions;
	mslc_default_options(&mslcOptions);

	// `options` is accepted and not read, because this framework's
	// MTLCompileOptions declares no properties: an options object here carries no
	// state, so it cannot change the output and nothing is being dropped. That is
	// not true of Apple's class, which has fastMathEnabled, languageVersion and
	// libraryPath. When those are added here, the ones mslc cannot honour have to
	// be refused rather than ignored, in this method and nowhere else: an app that
	// asks for a language version it does not get must get an error, not a library
	// compiled at a different version than it asked for.

	uint8_t* spirv = NULL;
	size_t spirvSize = 0;
	char* reflection = NULL;
	char* diagnostic = NULL;

	int translated = mslc_translate(
		static_cast<const char*>([utf8 bytes]), [utf8 length], &mslcOptions,
		&spirv, &spirvSize, &reflection, &diagnostic);

	if (translated != 0) {
		NSString* reason = (diagnostic != NULL)
			? [NSString stringWithUTF8String: diagnostic]
			: @"mslc reported a failure with no diagnostic";

		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat: @"mslc could not compile the source: %@", reason],
				MTLLibraryErrorCompileFailure);
		}

		mslc_free(spirv);
		mslc_free(reflection);
		mslc_free(diagnostic);
		return nil;
	}

	Indium::LibraryReflection libraryReflection;
	NSString* reflectionError = nil;

	if (!MTLReadMSLReflection(reflection, (reflection != NULL) ? strlen(reflection) : 0,
		libraryReflection, reflectionError))
	{
		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat:
					@"mslc compiled the source but its reflection cannot be used: %@",
					reflectionError],
				MTLLibraryErrorUnsupported);
		}

		mslc_free(spirv);
		mslc_free(reflection);
		mslc_free(diagnostic);
		return nil;
	}

	std::string indiumError;
	auto library = _device->newLibrary(spirv, spirvSize, libraryReflection, &indiumError);

	// indium borrows the module and the reflection for the call and nothing
	// longer, so both go back before the library is handed out rather than after
	// it is used.
	mslc_free(spirv);
	mslc_free(reflection);
	mslc_free(diagnostic);

	if (!library) {
		if (error) {
			*error = MSLLibraryError(
				[NSString stringWithFormat: @"indium refused the module mslc produced: %s",
					indiumError.empty() ? "no reason given" : indiumError.c_str()],
				MTLLibraryErrorCompileFailure);
		}
		return nil;
	}

	return [[MTLLibraryInternal alloc] initWithLibrary: library device: self];
}

- (BOOL) isLowPower {
	return NO;
}

- (BOOL) isHeadless {
	return NO;
}

- (BOOL) isRemovable {
	return NO;
}

#else

MTL_UNSUPPORTED_CLASS

#endif

- (BOOL) supportsFamily: (MTLGPUFamily)family {
	// See the note in MTLDevice.h. indium cannot report a GPU family, so this
	// answers for the Apple Silicon generation this was verified against and
	// declines every other. Declining is the safe direction: a caller that
	// believes it is on a family we do not claim will pick a path indium may not
	// be able to run, while a caller told NO takes the conservative one.
	return family == MTLGPUFamilyApple1;
}

- (BOOL) supportsShaderBarycentricCoordinates {
	// See the note in MTLDevice.h: Vulkan has no barycentric decoration to lower
	// onto, so this says what the backend implements.
	return NO;
}

- (BOOL) argumentBuffersSupport {
	// See the note in MTLDevice.h: indium does not implement argument buffers, so
	// this reports what the backend can do rather than what the GPU is.
	return NO;
}

- (BOOL) supportsTextureSampleCount: (NSUInteger)count {
	/* MSL only supports a single sample per pixel; no multisampling is implemented
	 * here, so anything other than 1 is refused rather than silently wrong. */
	return count == 1;
}

@end
