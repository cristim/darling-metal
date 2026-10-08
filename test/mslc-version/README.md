# Compiler/reader reflection version agreement

The authored public Metal fixture compiles a single kernel through
`newLibraryWithSource:options:error:`, dispatches16 elements and verifies every
shared-buffer value is123. It uses public vendored Metal headers only.

Before updating the compiler pin, the private committed runtime with mslc242e01e
returns nil with MTLLibraryErrorDomain: reflectionversion1 cannot be read by the
version2 reader. That compiler source explicitly emits version1; the existing
Metal MTLMSLReflection.mm reader explicitly requiresversion2. Published mslc
413bf6c introduces multi-entry compilation and version2 reflection;93938fb pins
that implementation plus its published follow-up tests (clean-room rung1/2).
The baseline API observation is rung4. No compiled guest shaders are inspected.

Exact private compile recipe used for the baseline (adjust independent paths):

```sh
flock /tmp/agent-locks/darling-heavy-build.lock python3 \
  /home/cristi/tmp-opencode/metal-resume/build-cpp-probe.py \
  test/mslc-version/source-api.mm /tmp/source-api \
  src/external/metal/Metal src/external/foundation/Foundation \
  src/external/corefoundation/CoreFoundation \
  src/external/objc4/runtime/libobjc.A.dylib
```

The helper reads the independent build's Indium compiler flags and Darwin linker
recipe; it does not alter its configuration. Run with the non-setuid build
launcher, a fresh DPREFIX, private DARLING_INSTALL_PREFIX, DARLING_ENABLE_METAL=1
and explicit native VK_DRIVER_FILES=/usr/share/vulkan/icd.d/asahi_icd.json. The
baseline exits1 with the reflection diagnostic; candidate verification pending.
Use prefix-scoped `darling shutdown` afterward. This compute test does not claim
success for source graphics or bundled precompiled application shader libraries.
