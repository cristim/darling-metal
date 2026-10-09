#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>

// The two selectors are declared here so the client compiles against a Metal that
// lacks them and fails at run time with the unrecognised selector, not at build time.
@protocol PlatformSelectors
@property(readonly) BOOL hasUnifiedMemory;
@property(readonly) uint64_t registryID;
@end

static int check(int ok, const char *what) {
  printf("%s %s\n", ok ? "ok  " : "FAIL", what);
  return ok ? 0 : 1;
}

int main(void) {
 @autoreleasepool {
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) { puts("FAIL no device"); return 2; }
  int failed = 0;
  failed += check([device respondsToSelector:@selector(hasUnifiedMemory)], "responds to hasUnifiedMemory");
  failed += check([device respondsToSelector:@selector(registryID)], "responds to registryID");
  if (failed) { puts("FAIL"); return 1; }

  id<MTLDevice, PlatformSelectors> d = (id<MTLDevice, PlatformSelectors>)device;
  BOOL unified = d.hasUnifiedMemory;
  uint64_t registryID = d.registryID;
  printf("name '%s' hasUnifiedMemory %d registryID 0x%016llx\n", [device.name UTF8String], (int)unified, (unsigned long long)registryID);

  failed += check(unified == YES || unified == NO, "hasUnifiedMemory is a BOOL");
  failed += check(registryID != 0, "registryID is non-zero");
  failed += check(d.registryID == registryID, "registryID is stable across calls");

  id<MTLDevice, PlatformSelectors> again = (id<MTLDevice, PlatformSelectors>)MTLCreateSystemDefaultDevice();
  failed += check(again.registryID == registryID, "registryID is stable across device objects");

  NSArray<id<MTLDevice>> *all = MTLCopyAllDevices();
  for (NSUInteger i = 0; i < all.count; i++)
    for (NSUInteger j = i + 1; j < all.count; j++)
      failed += check(((id<MTLDevice, PlatformSelectors>)all[i]).registryID != ((id<MTLDevice, PlatformSelectors>)all[j]).registryID, "registryID differs between devices");

  puts(failed ? "FAIL" : "PASS");
  return failed != 0;
 }
}
