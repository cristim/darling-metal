Guest test: `-[MTLDevice hasUnifiedMemory]` and `-[MTLDevice registryID]` exist and answer within
their documented ranges. Blender 5.1.2 reads both in its Metal `platform_init` and otherwise dies
with an unrecognised-selector exception.

Checks: both selectors are responded to; `hasUnifiedMemory` is a BOOL; `registryID` is non-zero,
stable across calls and across device objects, and distinct between the devices
`MTLCopyAllDevices` returns. The test prints the values, because the documented range of
`hasUnifiedMemory` (YES or NO) does not say which one a given machine must give. On Honeykrisp
(Apple M1, every device-local memory type is also host-visible) the value is 1.

Build and run like `render-pass-depth-attachment`:

```sh
python3 build-probe.py test/device-platform-selectors/client.m "$OUT/client" "$METAL"
env DARLING_ENABLE_METAL=1 DPREFIX="$PREFIX" DARLING_INSTALL_PREFIX="$RUNTIME/image/usr/local" "$RUNTIME/darling" shell env DARLING_ENABLE_METAL=1 "/Volumes/SystemRoot$OUT/client"
```

Before: `FAIL responds to hasUnifiedMemory`, `FAIL responds to registryID`, exit 1.
After: `PASS`, exit 0. Both are UNVERIFIED until built: the 2026-10-09 run of this change was
source-only (build slot held by another agent, low memory).

Provenance: rung 3, developer.apple.com MTLDevice `hasUnifiedMemory` and `registryID`;
rung 4, authored client. No Apple binary was inspected.
