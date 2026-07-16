import Combine
import CoreGraphics
import Darwin
import Foundation
import IOKit
import IOKit.hid

struct MouseDeviceDescriptor: Identifiable, Equatable, Hashable {
    let identifier: String
    let name: String
    let vendorID: Int
    let productID: Int
    let serialNumber: String?
    let transport: String?
    let locationID: Int?

    var id: String { identifier }
}

enum ExternalMouseEligibility {
    static func isSupported(
        name: String,
        transport: String?,
        isBuiltIn: Bool,
        pointerAccelerationType: String? = nil
    ) -> Bool {
        guard !isBuiltIn else {
            return false
        }

        if transport?.localizedCaseInsensitiveCompare(kIOHIDTransportVirtualValue) == .orderedSame {
            return false
        }

        if name.localizedCaseInsensitiveContains("trackpad")
            || name.localizedCaseInsensitiveContains("magic mouse") {
            return false
        }

        return pointerAccelerationType?.localizedCaseInsensitiveContains("trackpad") != true
    }
}

enum MouseDeviceIdentity {
    static func identifier(
        vendorID: Int,
        productID: Int,
        serialNumber: String?,
        transport: String?,
        locationID: Int?,
        name: String
    ) -> String {
        let vendorProduct = String(format: "%04X:%04X", vendorID, productID)
        if let serialNumber = normalized(serialNumber) {
            return "\(vendorProduct):serial:\(serialNumber.lowercased())"
        }

        let transport = normalized(transport)?.lowercased() ?? "unknown"
        let name = normalized(name)?.lowercased() ?? "mouse"
        if vendorID == 0, productID == 0, let locationID, locationID != 0 {
            return "\(vendorProduct):location:\(String(locationID, radix: 16))"
        }
        if vendorID != 0 || productID != 0 {
            return "\(vendorProduct):\(transport)"
        }
        return "\(vendorProduct):\(transport):\(name)"
    }

    static func legacyNamedIdentifier(
        vendorID: Int,
        productID: Int,
        serialNumber: String?,
        transport: String?,
        name: String
    ) -> String? {
        guard normalized(serialNumber) == nil,
              vendorID != 0 || productID != 0 else {
            return nil
        }
        let vendorProduct = String(format: "%04X:%04X", vendorID, productID)
        let transport = normalized(transport)?.lowercased() ?? "unknown"
        let name = normalized(name)?.lowercased() ?? "mouse"
        return "\(vendorProduct):\(transport):\(name)"
    }

    static func legacyLocationIdentifier(
        vendorID: Int,
        productID: Int,
        serialNumber: String?,
        locationID: Int?
    ) -> String? {
        guard normalized(serialNumber) == nil,
              let locationID,
              locationID != 0 else {
            return nil
        }
        return String(
            format: "%04X:%04X:location:%x",
            vendorID,
            productID,
            locationID
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value.replacingOccurrences(of: "|", with: "_")
    }
}

final class MouseDeviceMonitor: ObservableObject {
    @Published private(set) var devices: [MouseDeviceDescriptor] = []
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastActiveDeviceIdentifier: String?

    private enum ActivityKind: Equatable {
        case button(number: Int, isDown: Bool)
        case scroll
        case pointer
    }

    private struct Activity {
        let deviceIdentifier: String
        let kind: ActivityKind
        let timestamp: UInt64
        let observedUptimeNanoseconds: UInt64
    }

    private struct HeldButtonKey: Hashable {
        let buttonNumber: Int
        let deviceIdentifier: String
    }

    private struct HeldButton {
        let timestamp: UInt64
    }

    // CGEvent timestamps are nanoseconds while IOHIDValue timestamps use
    // mach absolute-time ticks. Keep every recorded timestamp in nanoseconds.
    private static let timestampToleranceNanoseconds: UInt64 = 12_000_000
    private static let fallbackActivityAgeNanoseconds: UInt64 = 150_000_000
    private static let recentActivityLimit = 512
    private static let machTimebase: (numerator: UInt64, denominator: UInt64) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (
            numerator: max(UInt64(info.numer), 1),
            denominator: max(UInt64(info.denom), 1)
        )
    }()

    private let manager: IOHIDManager
    private let stateLock = NSLock()
    private var descriptorsByRegistryID = [UInt64: MouseDeviceDescriptor]()
    private var recentActivities = [Activity]()
    private var recentPointerActivity: Activity?
    private var heldButtons = [HeldButtonKey: HeldButton]()

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        configureManager()
    }

    func stopMonitoring() {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        isMonitoring = false
        lastActiveDeviceIdentifier = nil
    }

    func deviceIdentifier(
        for eventType: CGEventType,
        event: CGEvent,
        buttonNumber: Int? = nil
    ) -> String? {
        let targetKind: ActivityKind
        let requiresExactMatch: Bool
        switch eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard let buttonNumber else { return recentDeviceIdentifier() }
            targetKind = .button(number: buttonNumber, isDown: true)
            requiresExactMatch = buttonNumber <= 1
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            guard let buttonNumber else { return recentDeviceIdentifier() }
            targetKind = .button(number: buttonNumber, isDown: false)
            requiresExactMatch = buttonNumber <= 1
        case .scrollWheel:
            targetKind = .scroll
            // A missing raw wheel event normally means this CGEvent came from
            // a trackpad. Do not fall back to the only connected mouse.
            requiresExactMatch = true
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if let buttonNumber {
                stateLock.lock()
                let candidates = heldButtons.keys.filter { $0.buttonNumber == buttonNumber }
                let identifier = candidates.count == 1 ? candidates[0].deviceIdentifier : nil
                stateLock.unlock()
                if let identifier {
                    return identifier
                }
                if buttonNumber <= 1 {
                    return nil
                }
            }
            return recentDeviceIdentifier()
        default:
            return recentDeviceIdentifier()
        }

        stateLock.lock()
        let eventTimestamp = event.timestamp
        let matchIndex = recentActivities.indices
            .reversed()
            .filter { recentActivities[$0].kind == targetKind }
            .min { leftIndex, rightIndex in
                Self.timestampDistance(
                    recentActivities[leftIndex].timestamp,
                    eventTimestamp
                ) < Self.timestampDistance(
                    recentActivities[rightIndex].timestamp,
                    eventTimestamp
                )
            }
        let identifier: String?
        if let matchIndex,
           Self.timestampDistance(recentActivities[matchIndex].timestamp, eventTimestamp)
                <= Self.timestampToleranceNanoseconds {
            let matchedActivity = recentActivities.remove(at: matchIndex)
            identifier = matchedActivity.deviceIdentifier
            if matchedActivity.kind == .scroll {
                recentActivities.removeAll {
                    $0.kind == .scroll
                        && $0.deviceIdentifier == matchedActivity.deviceIdentifier
                        && $0.timestamp == matchedActivity.timestamp
                }
            }
        } else if requiresExactMatch {
            // Primary clicks and scrolls may come from a trackpad. Never attribute
            // them to an external mouse without a matching raw HID event.
            identifier = nil
        } else if case let .button(number, isDown) = targetKind, isDown,
                  let held = mostRecentHeldButtonLocked(number: number) {
            identifier = held.deviceIdentifier
        } else {
            identifier = recentFallbackLocked()
        }
        stateLock.unlock()
        return identifier
    }

    func descriptor(for identifier: String?) -> MouseDeviceDescriptor? {
        guard let identifier else { return nil }
        return devices.first(where: { $0.identifier == identifier })
    }

    func hasHeldButton(number: Int) -> Bool {
        stateLock.lock()
        let isHeld = heldButtons.keys.contains { $0.buttonNumber == number }
        stateLock.unlock()
        return isHeld
    }

    func refreshAuthorization() {
        stateLock.lock()
        recentActivities.removeAll()
        recentPointerActivity = nil
        heldButtons.removeAll()
        stateLock.unlock()
        lastActiveDeviceIdentifier = nil
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        updateOpenStatus(IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)))
    }

    private func configureManager() {
        let mouseMatch: [String: Any] = [
            kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Mouse)
        ]
        IOHIDManagerSetDeviceMatching(manager, mouseMatch as CFDictionary)

        let buttonInputMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_Button)
        ]
        let wheelInputMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDElementUsageKey: Int(kHIDUsage_GD_Wheel)
        ]
        let horizontalWheelInputMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_Consumer),
            kIOHIDElementUsageKey: Int(kHIDUsage_Csmr_ACPan)
        ]
        let pointerXInputMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDElementUsageKey: Int(kHIDUsage_GD_X)
        ]
        let pointerYInputMatch: [String: Any] = [
            kIOHIDElementUsagePageKey: Int(kHIDPage_GenericDesktop),
            kIOHIDElementUsageKey: Int(kHIDUsage_GD_Y)
        ]
        IOHIDManagerSetInputValueMatchingMultiple(
            manager,
            [
                buttonInputMatch,
                wheelInputMatch,
                horizontalWheelInputMatch,
                pointerXInputMatch,
                pointerYInputMatch
            ] as CFArray
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceRemovedCallback, context)
        IOHIDManagerRegisterInputValueCallback(manager, Self.inputValueCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        updateOpenStatus(IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)))
    }

    private func updateOpenStatus(_ result: IOReturn) {
        isMonitoring = result == kIOReturnSuccess
        lastError = result == kIOReturnSuccess
            ? nil
            : String(format: "IOHIDManagerOpen failed (0x%08X)", result)

        guard result != kIOReturnSuccess else {
            return
        }

        stateLock.lock()
        descriptorsByRegistryID.removeAll()
        recentActivities.removeAll()
        recentPointerActivity = nil
        heldButtons.removeAll()
        stateLock.unlock()
        devices = []
        lastActiveDeviceIdentifier = nil
    }

    private func handleDeviceMatched(_ device: IOHIDDevice) {
        guard let descriptor = Self.descriptor(for: device),
              Self.isSupportedMouse(descriptor, device: device) else {
            return
        }

        stateLock.lock()
        descriptorsByRegistryID[Self.registryID(for: device)] = descriptor
        let updatedDevices = Self.deduplicatedDescriptors(descriptorsByRegistryID.values)
        stateLock.unlock()
        devices = updatedDevices
    }

    private func handleDeviceRemoved(_ device: IOHIDDevice) {
        let registryID = Self.registryID(for: device)
        stateLock.lock()
        let removedIdentifier = descriptorsByRegistryID.removeValue(forKey: registryID)?.identifier
        let connectedIdentifiers = Set(descriptorsByRegistryID.values.map(\.identifier))
        if let removedIdentifier, !connectedIdentifiers.contains(removedIdentifier) {
            recentActivities.removeAll { $0.deviceIdentifier == removedIdentifier }
            if recentPointerActivity?.deviceIdentifier == removedIdentifier {
                recentPointerActivity = nil
            }
            heldButtons = heldButtons.filter { $0.key.deviceIdentifier != removedIdentifier }
        }
        let updatedDevices = Self.deduplicatedDescriptors(descriptorsByRegistryID.values)
        let shouldClearLastActive = removedIdentifier == lastActiveDeviceIdentifier
            && removedIdentifier.map { !connectedIdentifiers.contains($0) } == true
        stateLock.unlock()
        devices = updatedDevices
        if shouldClearLastActive {
            lastActiveDeviceIdentifier = nil
        }
    }

    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let registryID = Self.registryID(for: device)

        stateLock.lock()
        let cachedDescriptor = descriptorsByRegistryID[registryID]
        stateLock.unlock()

        guard let descriptor = cachedDescriptor ?? Self.descriptor(for: device),
              Self.isSupportedMouse(descriptor, device: device) else {
            return
        }

        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)
        let kind: ActivityKind?

        if usagePage == UInt32(kHIDPage_Button), (1...32).contains(usage) {
            kind = .button(number: Int(usage) - 1, isDown: integerValue != 0)
        } else if usagePage == UInt32(kHIDPage_GenericDesktop), usage == UInt32(kHIDUsage_GD_Wheel) {
            kind = integerValue == 0 ? nil : .scroll
        } else if usagePage == UInt32(kHIDPage_Consumer), usage == UInt32(kHIDUsage_Csmr_ACPan) {
            kind = integerValue == 0 ? nil : .scroll
        } else if usagePage == UInt32(kHIDPage_GenericDesktop),
                  usage == UInt32(kHIDUsage_GD_X) || usage == UInt32(kHIDUsage_GD_Y) {
            kind = integerValue == 0 ? nil : .pointer
        } else {
            kind = nil
        }

        guard let kind else {
            return
        }

        let activity = Activity(
            deviceIdentifier: descriptor.identifier,
            kind: kind,
            timestamp: Self.nanoseconds(
                fromMachAbsoluteTime: IOHIDValueGetTimeStamp(value)
            ),
            observedUptimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        )

        stateLock.lock()
        descriptorsByRegistryID[registryID] = descriptor
        if kind == .pointer {
            recentPointerActivity = activity
        } else {
            recentActivities.append(activity)
            if recentActivities.count > Self.recentActivityLimit {
                recentActivities.removeFirst(
                    recentActivities.count - Self.recentActivityLimit
                )
            }
        }
        if case let .button(number, isDown) = kind {
            let heldKey = HeldButtonKey(
                buttonNumber: number,
                deviceIdentifier: descriptor.identifier
            )
            if isDown {
                heldButtons[heldKey] = HeldButton(timestamp: activity.timestamp)
            } else {
                heldButtons.removeValue(forKey: heldKey)
            }
        }
        stateLock.unlock()

        if lastActiveDeviceIdentifier != descriptor.identifier {
            lastActiveDeviceIdentifier = descriptor.identifier
        }
    }

    private func recentDeviceIdentifier() -> String? {
        stateLock.lock()
        let identifier = recentFallbackLocked()
        stateLock.unlock()
        return identifier
    }

    private func recentFallbackLocked() -> String? {
        let activity: Activity?
        if let discreteActivity = recentActivities.last,
           let pointerActivity = recentPointerActivity {
            activity = discreteActivity.observedUptimeNanoseconds
                >= pointerActivity.observedUptimeNanoseconds
                ? discreteActivity
                : pointerActivity
        } else {
            activity = recentActivities.last ?? recentPointerActivity
        }

        guard let activity else {
            return devices.count == 1 ? devices[0].identifier : nil
        }

        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= activity.observedUptimeNanoseconds,
              now - activity.observedUptimeNanoseconds <= Self.fallbackActivityAgeNanoseconds else {
            return devices.count == 1 ? devices[0].identifier : nil
        }
        return activity.deviceIdentifier
    }

    private func mostRecentHeldButtonLocked(
        number: Int
    ) -> (deviceIdentifier: String, timestamp: UInt64)? {
        heldButtons
            .filter { $0.key.buttonNumber == number }
            .map { ($0.key.deviceIdentifier, $0.value.timestamp) }
            .max { $0.1 < $1.1 }
    }

    private static func descriptor(for device: IOHIDDevice) -> MouseDeviceDescriptor? {
        let name = stringProperty(kIOHIDProductKey, from: device)
            ?? stringProperty(kIOHIDManufacturerKey, from: device)
            ?? "External Mouse"
        let vendorID = integerProperty(kIOHIDVendorIDKey, from: device) ?? 0
        let productID = integerProperty(kIOHIDProductIDKey, from: device) ?? 0
        let serialNumber = stringProperty(kIOHIDSerialNumberKey, from: device)
        let transport = stringProperty(kIOHIDTransportKey, from: device)
        let locationID = integerProperty(kIOHIDLocationIDKey, from: device)
        return MouseDeviceDescriptor(
            identifier: MouseDeviceIdentity.identifier(
                vendorID: vendorID,
                productID: productID,
                serialNumber: serialNumber,
                transport: transport,
                locationID: locationID,
                name: name
            ),
            name: name,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            transport: transport,
            locationID: locationID
        )
    }

    private static func isSupportedMouse(
        _ descriptor: MouseDeviceDescriptor,
        device: IOHIDDevice
    ) -> Bool {
        ExternalMouseEligibility.isSupported(
            name: descriptor.name,
            transport: descriptor.transport,
            isBuiltIn: (integerProperty(kIOHIDBuiltInKey, from: device) ?? 0) != 0
        )
    }

    private static func deduplicatedDescriptors<S: Sequence>(
        _ descriptors: S
    ) -> [MouseDeviceDescriptor] where S.Element == MouseDeviceDescriptor {
        Dictionary(descriptors.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
            .values
            .sorted {
                if $0.name == $1.name {
                    return $0.identifier < $1.identifier
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private static func stringProperty(_ key: String, from device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func integerProperty(_ key: String, from device: IOHIDDevice) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func registryID(for device: IOHIDDevice) -> UInt64 {
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &registryID)
        return registryID
    }

    private static func timestampDistance(_ left: UInt64, _ right: UInt64) -> UInt64 {
        left >= right ? left - right : right - left
    }

    private static func nanoseconds(fromMachAbsoluteTime timestamp: UInt64) -> UInt64 {
        let numerator = machTimebase.numerator
        let denominator = machTimebase.denominator
        let whole = timestamp / denominator
        let remainder = timestamp % denominator
        return whole * numerator + remainder * numerator / denominator
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, result, _, device in
        guard result == kIOReturnSuccess, let context else {
            return
        }
        Unmanaged<MouseDeviceMonitor>.fromOpaque(context).takeUnretainedValue().handleDeviceMatched(device)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }
        Unmanaged<MouseDeviceMonitor>.fromOpaque(context).takeUnretainedValue().handleDeviceRemoved(device)
    }

    private static let inputValueCallback: IOHIDValueCallback = { context, result, _, value in
        guard result == kIOReturnSuccess, let context else {
            return
        }
        Unmanaged<MouseDeviceMonitor>.fromOpaque(context).takeUnretainedValue().handleInputValue(value)
    }
}
