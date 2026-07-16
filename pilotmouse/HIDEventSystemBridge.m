#import "MousePilot-Bridging-Header.h"

IOHIDEventSystemClientRef MPCreateHIDEventSystemClient(void) {
    return IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
}
