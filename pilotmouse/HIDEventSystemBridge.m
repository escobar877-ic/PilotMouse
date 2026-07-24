#import "MousePilot-Bridging-Header.h"

extern IOHIDEventSystemClientRef _Nullable IOHIDEventSystemClientCreate(
    CFAllocatorRef _Nullable allocator
);

IOHIDEventSystemClientRef MPCreateHIDEventSystemClient(void) {
    // A simple client can enumerate services but returns nil for dynamic
    // pointer properties and rejects their writes on current macOS releases.
    IOHIDEventSystemClientRef client =
        IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (client != NULL) {
        return client;
    }

    return IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
}
