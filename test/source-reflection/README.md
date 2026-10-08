# Source reflection resources

Authored JSON uses published mslc c745234 src/sema.cpp resource/embedded sampler emission and src/ast.cpp enum names. Indium library.hpp specifies the typed consumer. No compiled guest shader inputs.

Build against a configured arm64 Darling tree, using its production Metal flags:

```
flock /tmp/agent-locks/darling-heavy-build.lock python3 test/source-reflection/build.py /path/to/build /tmp/reflection-before --library /path/to/baseline/Metal
flock /tmp/agent-locks/darling-heavy-build.lock python3 test/source-reflection/build.py /path/to/build /tmp/reflection-after --library /path/to/baseline/Metal --candidate
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shell env DARLING_ENABLE_METAL=1 /Volumes/SystemRoot/tmp/reflection-before
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shell env DARLING_ENABLE_METAL=1 /Volumes/SystemRoot/tmp/reflection-after
DPREFIX=/path/to/private/prefix DARLING_INSTALL_PREFIX=/path/to/private/image/usr/local /path/to/nonsetuid/darling shutdown
```

Measured with /home/cristi/tmp-opencode/metal-resume/build and baseline latest-source-build/Metal (a3f12e0): exit1, Buffer passes; sampled/storage textures and external/embedded samplers fail. Candidate exit0, all15 checks pass. Check binding type, stage, Metal/descriptor indices, all embedded fields; reject unknown access/address, invalid embedded index, numeric boolean substitute, null/inverted LOD, missing sampler list, boolean anisotropy, wrong descriptor set, conflicting external/embedded indices.

The reader accepts only producer-supported Sample/Write texture access and sampler names/states. Parser Write acceptance is not GPU storage-texture verification. Buffer-only version2 documents with no embedded_samplers remain valid. Unknown new schema values reject explicitly. Native sampled texture validation follows through public newLibraryWithSource and exact RGBA readback in the independent source-graphics fixture.
