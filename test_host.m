// test_host.m
// Minimal macOS host that loads yeeps_companion.dylib at runtime.
// Build & run this to test without injection.
//
// Compile:
//   clang -fobjc-arc -fmodules -framework Cocoa -o test_host test_host.m
// Run:
//   ./test_host

#import <Cocoa/Cocoa.h>
#include <dlfcn.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];

        // Derive path: dylib sits next to this binary
        NSString *dir  = [[[NSBundle mainBundle] bundlePath]
                           stringByDeletingLastPathComponent];
        NSString *dylib = [dir stringByAppendingPathComponent:
                           @"yeeps_companion.dylib"];

        NSLog(@"Loading: %@", dylib);
        void *handle = dlopen(dylib.UTF8String, RTLD_NOW);
        if (!handle) {
            NSLog(@"❌ dlopen failed: %s", dlerror());
            return 1;
        }
        NSLog(@"✅ Loaded — Yeeps Companion GUI should now be visible.");

        [NSApp run]; // keep app alive so the window stays open
    }
    return 0;
}
