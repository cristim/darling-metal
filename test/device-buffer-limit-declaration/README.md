Add only the published public declaration. Apple's Objective-C documentation declares `@property (readonly) NSUInteger maxBufferLength`; this change adds no getter implementation, capacity policy or successful runtime-query claim. The existing device still rejects that selector until a separate implementation is supplied.

From this repository root, with the measured Darling source/build SDK:

```sh
header_darling_source=/home/cristi/tmp-opencode/metal-resume/darling
header_darling_build=/home/cristi/tmp-opencode/metal-resume/build
flock /tmp/agent-locks/darling-heavy-build.lock clang -target aarch64-apple-darwin20 -fblocks -fsyntax-only -Wno-nullability-completeness -Wno-deprecated-declarations -Wno-expansion-to-defined -I"$header_darling_source/framework-include" -I"$header_darling_source/basic-headers" -I"$header_darling_source/src/include" -I"$header_darling_build/src/include" -I"$header_darling_source/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" -I"$header_darling_build/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include" test/device-buffer-limit-declaration/client.m
```

The donor header fails1 at the property access. Repeat with `-I"$PWD/include"` before those SDK includes for candidate compile0. This reproduces one compile blocker in published MIT DodgeDanger's device-sort comparator; it does not establish whether that comparator invokes the getter during a game run.

Provenance: rung3 https://developer.apple.com/documentation/metal/mtldevice/maxbufferlength and its public documentation JSON Objective-C declaration; rung4 authored syntax client. No Apple binary/header dump or invented limit is used.
