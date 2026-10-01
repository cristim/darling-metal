// SPDX-License-Identifier: MPL-2.0
//
// Guest test for the Metal classes added for Blender's dyld failures.
//
// Every check is on a value the caller itself supplied, so a pass means the
// object stored and returned that value and nothing else. Checks marked LOUD
// assert the opposite: that an unsupported operation refuses rather than
// answering plausibly.
//
// NEGATIVE CONTROL: MTL_EXPECT_NEGATIVE is defined in the build script for the
// second run, which inverts every MTL_EXPECT to MTL_EXPECT_NEGATIVE. That run
// must FAIL on the first check. If it passes, the assertions are not asserting
// anything and the passing run means nothing either.

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int gFailures = 0;

static void mtlCheck(BOOL ok, const char* what)
{
	if (!ok) {
		gFailures++;
		printf("FAIL  %s\n", what);
	} else {
		printf("ok    %s\n", what);
	}
	fflush(stdout);
}

#ifdef NEGATIVE
#define MTL_EXPECT(cond, what)   mtlCheck(!(cond), (what))
#define MTL_EXPECT_NEGATIVE(cond, what) mtlCheck((cond), (what))
#else
#define MTL_EXPECT(cond, what)   mtlCheck((cond), (what))
#define MTL_EXPECT_NEGATIVE(cond, what) mtlCheck(!(cond), (what))
#endif

int main(void)
{
	@autoreleasepool {
		// ------------------------------------------------ MTLArgumentDescriptor
		{
			MTLArgumentDescriptor* d = [MTLArgumentDescriptor argumentDescriptor];
			MTL_EXPECT(d != nil, "MTLArgumentDescriptor +argumentDescriptor returns an object");

			d.index = 7;
			d.dataType = MTLDataTypeFloat4x4;
			d.access = MTLArgumentAccessWriteOnly;
			d.arrayLength = 64;
			d.textureType = MTLTextureType2DArray;
			d.constantBlockAlignment = 256;

			MTL_EXPECT(d.index == 7, "argumentDescriptor.index round-trips");
			MTL_EXPECT(d.dataType == MTLDataTypeFloat4x4, "argumentDescriptor.dataType round-trips");
			MTL_EXPECT(d.access == MTLArgumentAccessWriteOnly, "argumentDescriptor.access round-trips");
			MTL_EXPECT(d.arrayLength == 64, "argumentDescriptor.arrayLength round-trips");
			MTL_EXPECT(d.textureType == MTLTextureType2DArray, "argumentDescriptor.textureType round-trips");
			MTL_EXPECT(d.constantBlockAlignment == 256, "argumentDescriptor.constantBlockAlignment round-trips");

			MTLArgumentDescriptor* c = [d copy];
			MTL_EXPECT(c != d, "copyWithZone: returns a distinct object");
			MTL_EXPECT(c.index == 7 && c.dataType == MTLDataTypeFloat4x4,
				"copyWithZone: carries the values across");

			// Independence: writing the copy must not touch the original.
			c.index = 999;
			MTL_EXPECT(d.index == 7, "writing the copy does not change the original");

			// The value is the caller's, not a default that happens to match.
			MTLArgumentDescriptor* blank = [MTLArgumentDescriptor argumentDescriptor];
			MTL_EXPECT(blank.index == 0 && blank.dataType == MTLDataTypeNone,
				"a fresh argumentDescriptor reads back the zero value, not 7");
		}

		// ------------------------------------------------ MTLHeapDescriptor
		{
			MTLHeapDescriptor* h = [MTLHeapDescriptor new];
			h.size = 4096;
			h.storageMode = MTLStorageModePrivate;
			h.cpuCacheMode = MTLCPUCacheModeWriteCombined;
			h.hazardTrackingMode = MTLHazardTrackingModeTracked;
			h.type = MTLHeapTypePlacement;

			MTL_EXPECT(h.size == 4096, "heapDescriptor.size round-trips");
			MTL_EXPECT(h.storageMode == MTLStorageModePrivate, "heapDescriptor.storageMode round-trips");
			MTL_EXPECT(h.cpuCacheMode == MTLCPUCacheModeWriteCombined, "heapDescriptor.cpuCacheMode round-trips");
			MTL_EXPECT(h.hazardTrackingMode == MTLHazardTrackingModeTracked, "heapDescriptor.hazardTrackingMode round-trips");
			MTL_EXPECT(h.type == MTLHeapTypePlacement, "heapDescriptor.type round-trips");

			// The documented two-way reflection between resourceOptions and the modes.
			MTLResourceOptions o = h.resourceOptions;
			MTL_EXPECT((o & (MTLResourceStorageModePrivate)) == MTLResourceStorageModePrivate,
				"resourceOptions reflects the storage mode that was set");
			MTL_EXPECT((o & MTLResourceCPUCacheModeWriteCombined) == MTLResourceCPUCacheModeWriteCombined,
				"resourceOptions reflects the CPU cache mode that was set");
			MTL_EXPECT((o & MTLResourceHazardTrackingModeTracked) == MTLResourceHazardTrackingModeTracked,
				"resourceOptions reflects the hazard tracking mode that was set");

			// And the other direction.
			MTLHeapDescriptor* g = [MTLHeapDescriptor new];
			g.resourceOptions = MTLResourceStorageModeManaged;
			MTL_EXPECT(g.storageMode == MTLStorageModeManaged,
				"setting resourceOptions decomposes into storageMode");
		}

		// ------------------------------------------------ MTLCaptureDescriptor + LOUD
		{
			MTLCaptureDescriptor* cap = [MTLCaptureDescriptor new];
			cap.destination = MTLCaptureDestinationGPUTraceDocument;
			MTL_EXPECT(cap.destination == MTLCaptureDestinationGPUTraceDocument,
				"captureDescriptor.destination round-trips");

			// LOUD: capture must refuse, not claim success.
			NSError* err = nil;
			MTLCaptureManager* mgr = [MTLCaptureManager sharedCaptureManager];
			MTL_EXPECT(mgr != nil, "+sharedCaptureManager returns an object");
			BOOL started = [mgr startCaptureWithDescriptor: cap error: &err];
			MTL_EXPECT_NEGATIVE(started, "startCaptureWithDescriptor:error: refuses");
			MTL_EXPECT(err != nil, "startCaptureWithDescriptor:error: sets an NSError");
			MTL_EXPECT(err != nil && [err.domain isEqualToString: MTLCaptureErrorDomain],
				"the NSError is in MTLCaptureErrorDomain");
			MTL_EXPECT(err != nil && err.code == MTLCaptureErrorNotSupported,
				"the NSError code is MTLCaptureErrorNotSupported");
			MTL_EXPECT(mgr.isCapturing == NO, "isCapturing is NO after a refused capture");
		}

		// ------------------------------------------------ MTLSharedEventListener
		{
			MTLSharedEventListener* l = [MTLSharedEventListener sharedListener];
			MTL_EXPECT(l != nil, "+sharedListener returns an object");
			MTL_EXPECT(l.dispatchQueue != NULL, "dispatchQueue is non-NULL, as the property promises");
			MTL_EXPECT([MTLSharedEventListener sharedListener] == l, "+sharedListener is a singleton");

			dispatch_queue_t q = dispatch_queue_create("mtl.test.queue", NULL);
			MTLSharedEventListener* mine = [[MTLSharedEventListener alloc] initWithDispatchQueue: q];
			MTL_EXPECT(mine.dispatchQueue == q, "initWithDispatchQueue: hands back the same queue");
		}

		// ------------------------------------------------ MTLLinkedFunctions
		{
			MTLLinkedFunctions* lf = [MTLLinkedFunctions new];
			NSArray* fns = [NSArray arrayWithObjects: @"a", @"b", nil];
			lf.functions = fns;
			lf.groups = [NSDictionary dictionaryWithObject: fns forKey: @"g"];
			MTL_EXPECT(lf.functions == fns, "linkedFunctions.functions round-trips the same array");
			MTL_EXPECT(lf.groups != nil && [lf.groups objectForKey: @"g"] == fns,
				"linkedFunctions.groups round-trips the same dictionary");
		}

		// ------------------------------------------------ MTLCommandBufferDescriptor
		{
			MTLCommandBufferDescriptor* cb = [MTLCommandBufferDescriptor new];
			cb.retainedReferences = YES;
			cb.errorOptions = MTLCommandBufferErrorOptionEncoderExecutionStatus;
			MTL_EXPECT(cb.retainedReferences == YES, "commandBufferDescriptor.retainedReferences round-trips");
			MTL_EXPECT(cb.errorOptions == MTLCommandBufferErrorOptionEncoderExecutionStatus,
				"commandBufferDescriptor.errorOptions round-trips");
		}

		// ------------------------------------------------ MTLCounterSampleBufferDescriptor
		{
			MTLCounterSampleBufferDescriptor* cs = [MTLCounterSampleBufferDescriptor new];
			cs.sampleCount = 128;
			cs.storageMode = MTLStorageModeShared;
			cs.label = @"counters";
			MTL_EXPECT(cs.sampleCount == 128, "counterSampleBufferDescriptor.sampleCount round-trips");
			MTL_EXPECT(cs.storageMode == MTLStorageModeShared, "counterSampleBufferDescriptor.storageMode round-trips");
			MTL_EXPECT([cs.label isEqualToString: @"counters"], "counterSampleBufferDescriptor.label round-trips");

			MTLCounterSampleBufferDescriptor* fresh = [MTLCounterSampleBufferDescriptor new];
			MTL_EXPECT(fresh.sampleCount == 0, "a fresh counter sample buffer descriptor has sampleCount 0");
		}

		// ------------------------------------------------ geometry descriptors
		{
			MTLAccelerationStructureTriangleGeometryDescriptor* tri =
				[MTLAccelerationStructureTriangleGeometryDescriptor new];
			tri.triangleCount = 3;
			tri.vertexStride = 32;
			tri.vertexFormat = MTLAttributeFormatFloat3;
			tri.indexType = MTLIndexTypeUInt32;
			tri.transformationMatrixLayout = MTLMatrixLayoutRowMajor;
			tri.vertexBufferOffset = 16;
			MTL_EXPECT(tri.triangleCount == 3, "triangle geometry triangleCount round-trips");
			MTL_EXPECT(tri.vertexStride == 32, "triangle geometry vertexStride round-trips");
			MTL_EXPECT(tri.vertexFormat == MTLAttributeFormatFloat3, "triangle geometry vertexFormat round-trips");
			MTL_EXPECT(tri.indexType == MTLIndexTypeUInt32, "triangle geometry indexType round-trips");
			MTL_EXPECT(tri.transformationMatrixLayout == MTLMatrixLayoutRowMajor,
				"triangle geometry transformationMatrixLayout round-trips");
			MTL_EXPECT(tri.vertexBufferOffset == 16, "triangle geometry vertexBufferOffset round-trips");

			MTLAccelerationStructureTriangleGeometryDescriptor* tc = [tri copy];
			MTL_EXPECT(tc != tri, "geometry copyWithZone: returns a distinct object");
			MTL_EXPECT(tc.triangleCount == 3 && tc.vertexStride == 32,
				"geometry copyWithZone: carries the values across");
			tc.triangleCount = 99;
			MTL_EXPECT(tri.triangleCount == 3, "writing the geometry copy does not change the original");

			MTLAccelerationStructureBoundingBoxGeometryDescriptor* bb =
				[MTLAccelerationStructureBoundingBoxGeometryDescriptor new];
			bb.boundingBoxCount = 12;
			bb.boundingBoxStride = 24;
			MTL_EXPECT(bb.boundingBoxCount == 12 && bb.boundingBoxStride == 24,
				"bounding box geometry count and stride round-trip");

			MTLAccelerationStructureMotionTriangleGeometryDescriptor* mt =
				[MTLAccelerationStructureMotionTriangleGeometryDescriptor new];
			mt.vertexBuffers = [NSArray array];
			mt.triangleCount = 5;
			MTL_EXPECT(mt.vertexBuffers != nil && mt.triangleCount == 5,
				"motion triangle geometry vertexBuffers and triangleCount round-trip");
		}

		// ------------------------------------------------ acceleration structure descriptors
		{
			MTLPrimitiveAccelerationStructureDescriptor* pas =
				[MTLPrimitiveAccelerationStructureDescriptor new];
			pas.motionStartTime = 0.5f;
			pas.motionEndTime = 1.5f;
			pas.motionKeyframeCount = 2;
			pas.motionStartBorderMode = MTLMotionBorderModeVanish;
			NSArray* geo = [NSArray arrayWithObject:
				[MTLAccelerationStructureTriangleGeometryDescriptor new]];
			pas.geometryDescriptors = geo;
			MTL_EXPECT(pas.motionStartTime == 0.5f, "primitive AS motionStartTime round-trips");
			MTL_EXPECT(pas.motionEndTime == 1.5f, "primitive AS motionEndTime round-trips");
			MTL_EXPECT(pas.motionKeyframeCount == 2, "primitive AS motionKeyframeCount round-trips");
			MTL_EXPECT(pas.motionStartBorderMode == MTLMotionBorderModeVanish,
				"primitive AS motionStartBorderMode round-trips");
			MTL_EXPECT(pas.geometryDescriptors == geo, "primitive AS geometryDescriptors round-trips the same array");

			MTLInstanceAccelerationStructureDescriptor* ias =
				[MTLInstanceAccelerationStructureDescriptor new];
			ias.instanceCount = 4;
			ias.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeMotion;
			ias.motionTransformType = MTLTransformTypeComponent;
			MTL_EXPECT(ias.instanceCount == 4, "instance AS instanceCount round-trips");
			MTL_EXPECT(ias.instanceDescriptorType == MTLAccelerationStructureInstanceDescriptorTypeMotion,
				"instance AS instanceDescriptorType round-trips");
			MTL_EXPECT(ias.motionTransformType == MTLTransformTypeComponent,
				"instance AS motionTransformType round-trips");
		}

		// ------------------------------------------------ MTLIntersectionFunctionTableDescriptor
		{
			MTLIntersectionFunctionTableDescriptor* t =
				[MTLIntersectionFunctionTableDescriptor intersectionFunctionTableDescriptor];
			MTL_EXPECT(t != nil, "+intersectionFunctionTableDescriptor returns an object");
			MTL_EXPECT(t.functionCount == 0, "a fresh function table descriptor has functionCount 0");
			t.functionCount = 9;
			MTL_EXPECT(t.functionCount == 9, "intersectionFunctionTableDescriptor.functionCount round-trips");

			// Declared, so dyld resolves it, and deliberately propertyless: setting
			// an invented property must be an unrecognised selector, not a guess.
			MTLIntersectionFunctionDescriptor* fd = [MTLIntersectionFunctionDescriptor new];
			MTL_EXPECT(fd != nil, "MTLIntersectionFunctionDescriptor allocates (dyld resolved it)");
		}

		// ------------------------------------------------ MTLTileRenderPipelineDescriptor
		{
			MTLTileRenderPipelineDescriptor* t = [MTLTileRenderPipelineDescriptor new];
			MTL_EXPECT(t.colorAttachments != nil, "tile descriptor colourAttachments is non-NULL");
			MTL_EXPECT(t.colorAttachments.count == 1, "tile descriptor starts with one colour attachment");
			MTL_EXPECT(t.rasterSampleCount == 1, "tile descriptor rasterSampleCount defaults to 1");

			t.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
			t.colorAttachments[0].storeAction = MTLStoreActionStore;
			MTL_EXPECT(t.colorAttachments[0].pixelFormat == MTLPixelFormatRGBA8Unorm,
				"tile colour attachment pixelFormat round-trips through the array");
			MTL_EXPECT(t.colorAttachments[0].storeAction == MTLStoreActionStore,
				"tile colour attachment storeAction round-trips through the array");

			t.rasterSampleCount = 4;
			t.maxTotalThreadsPerThreadgroup = 256;
			t.threadgroupSizeMatchesTileSize = YES;
			t.requiredThreadsPerThreadgroup = MTLSizeMake(8, 8, 1);
			MTL_EXPECT(t.rasterSampleCount == 4, "tile descriptor rasterSampleCount round-trips");
			MTL_EXPECT(t.maxTotalThreadsPerThreadgroup == 256, "tile descriptor maxTotalThreadsPerThreadgroup round-trips");
			MTL_EXPECT(t.threadgroupSizeMatchesTileSize == YES, "tile descriptor threadgroupSizeMatchesTileSize round-trips");
			MTL_EXPECT(t.requiredThreadsPerThreadgroup.width == 8 && t.requiredThreadsPerThreadgroup.height == 8,
				"tile descriptor requiredThreadsPerThreadgroup round-trips");

			MTLTileRenderPipelineDescriptor* tc = [t copy];
			MTL_EXPECT(tc != t, "tile descriptor copyWithZone: returns a distinct object");
			MTL_EXPECT(tc.colorAttachments != t.colorAttachments,
				"tile descriptor copy has its own colour attachment array, not an alias");
			MTL_EXPECT(tc.colorAttachments[0].pixelFormat == MTLPixelFormatRGBA8Unorm,
				"tile descriptor copy carries the attachment across");
			tc.colorAttachments[0].pixelFormat = MTLPixelFormatA8Unorm;
			MTL_EXPECT(t.colorAttachments[0].pixelFormat == MTLPixelFormatRGBA8Unorm,
				"mutating the copy's attachment does not change the original's");

			[t reset];
			MTL_EXPECT(t.rasterSampleCount == 1, "-reset puts rasterSampleCount back to 1");
			MTL_EXPECT(t.colorAttachments[0].pixelFormat == MTLPixelFormatInvalid,
				"-reset puts the attachment pixel format back to Invalid");
			MTL_EXPECT(t.maxTotalThreadsPerThreadgroup == 0, "-reset puts maxTotalThreadsPerThreadgroup back to 0");
		}

		// ------------------------------------------------ declared-with-no-properties
		{
			// MTLIntersectionFunctionDescriptor is declared with no properties on
			// purpose, because no reference on this machine says what its
			// properties are. Assert that directly: if a property ever appears on
			// it, this fails and someone has to go and find out where the name came
			// from.
			MTLIntersectionFunctionDescriptor* fd = [MTLIntersectionFunctionDescriptor new];
			MTL_EXPECT_NEGATIVE([fd respondsToSelector: @selector(function)],
				"MTLIntersectionFunctionDescriptor declares no 'function' property");
			MTL_EXPECT_NEGATIVE([fd respondsToSelector: @selector(buffer)],
				"MTLIntersectionFunctionDescriptor declares no 'buffer' property");
			MTL_EXPECT([fd respondsToSelector: @selector(copyWithZone:)],
				"MTLIntersectionFunctionDescriptor still responds to copyWithZone:");
		}

		// ------------------------------------------------ the un-backed operations
		{
			// The device methods each new descriptor exists to feed are not declared
			// at all, so a caller asking for one gets an unrecognised selector. That
			// is the loud failure; asserting it here is what stops a future change
			// from quietly adding a method that returns a plausible empty object.
			id<MTLDevice> device = MTLCreateSystemDefaultDevice();
			if (device != nil) {
				MTLHeapDescriptor* hd = [MTLHeapDescriptor new];
				(void)hd;
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newHeapWithDescriptor:error:)],
					"MTLDevice does not claim -newHeapWithDescriptor:error:");

				MTLBinaryArchiveDescriptor* bd = [MTLBinaryArchiveDescriptor new];
				(void)bd;
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newBinaryArchiveWithDescriptor:error:)],
					"MTLDevice does not claim -newBinaryArchiveWithDescriptor:error:");

				MTLCounterSampleBufferDescriptor* cd = [MTLCounterSampleBufferDescriptor new];
				(void)cd;
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newCounterSampleBufferWithDescriptor:error:)],
					"MTLDevice does not claim -newCounterSampleBufferWithDescriptor:error:");

				MTLPrimitiveAccelerationStructureDescriptor* pas =
					[MTLPrimitiveAccelerationStructureDescriptor new];
				(void)pas;
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newAccelerationStructureWithDescriptor:error:)],
					"MTLDevice does not claim -newAccelerationStructureWithDescriptor:error:");

				MTLTileRenderPipelineDescriptor* td = [MTLTileRenderPipelineDescriptor new];
				(void)td;
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newTileRenderPipelineStateWithDescriptor:error:)],
					"MTLDevice does not claim -newTileRenderPipelineStateWithDescriptor:error:");

				// -name is implemented, so this checks the answer rather than the
				// absence. What makes it worth asserting is that it is the
				// device's own name: the string below is what vulkaninfo reports
				// for the physical device indium enumerates first on this host.
				// A hard-coded expectation of that exact string would make this a
				// test of the host's GPU rather than of -name, so the checks are
				// on the properties any device name must have, and the harness
				// prints the value so it can be compared against vulkaninfo by
				// eye. Non-empty, and not one of the placeholder strings a
				// fabricated implementation would return.
				NSString* deviceName = [device name];
				printf("info  -name = \"%s\"\n",
					([deviceName length] > 0) ? [deviceName UTF8String] : "");
				MTL_EXPECT(deviceName != nil, "-name returns an object");
				MTL_EXPECT([deviceName length] > 0, "-name is not empty");
				MTL_EXPECT(![deviceName isEqualToString: @"<unnamed>"],
					"-name is a real name, not a placeholder");
				// The name comes back as UTF-8 that round-trips, which is what
				// makes it the device's own name and not a lossy re-encoding.
				MTL_EXPECT([[NSString stringWithUTF8String: [deviceName UTF8String]]
					isEqualToString: deviceName], "-name round-trips through UTF-8");

				// The other nine of the twelve selectors Blender 5.1.2 reaches
				// for. Each is a question indium cannot answer, so each must stay
				// absent: the unrecognised selector names the gap, where an
				// object that answered plausibly would not.
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newEvent)],
					"MTLDevice does not claim -newEvent");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newSharedEvent)],
					"MTLDevice does not claim -newSharedEvent");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newBinaryArchiveWithDescriptor:error:)],
					"MTLDevice does not claim -newBinaryArchiveWithDescriptor:error: (second check)");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newCounterSampleBufferWithDescriptor:error:)],
					"MTLDevice does not claim -newCounterSampleBufferWithDescriptor:error: (second check)");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newArgumentEncoderWithArguments:)],
					"MTLDevice does not claim -newArgumentEncoderWithArguments:");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newAccelerationStructureWithSize:)],
					"MTLDevice does not claim -newAccelerationStructureWithSize:");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(accelerationStructureSizesWithDescriptor:)],
					"MTLDevice does not claim -accelerationStructureSizesWithDescriptor:");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(newCommandQueueWithMaxCommandBufferCount:)],
					"MTLDevice does not claim -newCommandQueueWithMaxCommandBufferCount:");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(minimumLinearTextureAlignmentForPixelFormat:)],
					"MTLDevice does not claim -minimumLinearTextureAlignmentForPixelFormat:");

				// Two more that are questions about the hardware rather than about
				// this framework's plumbing. MTLGPUFamily is Apple's numbering of
				// silicon generations and Vulkan has no property that maps onto
				// it; indium has no query pool at all, so it has no counter
				// sampling point to report. Both would be a claim about real
				// hardware, so both stay absent.
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(supportsFamily:)],
					"MTLDevice does not claim -supportsFamily:");
				MTL_EXPECT_NEGATIVE([device respondsToSelector: @selector(supportsCounterSampling:)],
					"MTLDevice does not claim -supportsCounterSampling:");

				// The one that used to be a silent nil under a "TODO".
				id<MTLLibrary> lib = [device newDefaultLibrary];
				if (lib != nil) {
					NSArray* names = lib.functionNames;
					if (names != nil && [names count] > 0) {
						id<MTLFunction> fn = [lib newFunctionWithName: [names objectAtIndex: 0]];
						if (fn != nil) {
							id<MTLArgumentEncoder> enc = [fn newArgumentEncoderWithBufferIndex: 0];
							MTL_EXPECT_NEGATIVE(enc != nil,
								"newArgumentEncoderWithBufferIndex: returns nil, not a fabricated encoder");
						} else {
							printf("skip  newArgumentEncoderWithBufferIndex: (no function available)\n");
						}
					} else {
						printf("skip  newArgumentEncoderWithBufferIndex: (no function names)\n");
					}
				} else {
					printf("skip  newArgumentEncoderWithBufferIndex: (no default library)\n");
				}
			} else {
				printf("skip  device-dependent checks (no system default device)\n");
			}
		}

		printf("\n%s: %d failure(s)\n", gFailures == 0 ? "PASS" : "FAIL", gFailures);
		fflush(stdout);
	}

	return gFailures == 0 ? 0 : 1;
}
