import Foundation
import IOKit.hid
import IOKit.hidsystem

final class HIDPointerResolutionController {
    struct DeviceState {
        let id: String
        let profileIdentifier: String
        let name: String
        let acceleration: Double?
        let resolution: Double?
    }

    struct DeviceConfiguration: Equatable {
        let isEnabled: Bool
        let acceleration: Double
        let resolution: Double

        static let disabled = DeviceConfiguration(
            isEnabled: false,
            acceleration: 0,
            resolution: 400
        )
    }

    struct Snapshot {
        let devices: [DeviceState]
        let originalFirstAcceleration: Double?
        let originalFirstResolution: Double?
        let appliedAccelerationDeviceCount: Int
        let appliedResolutionDeviceCount: Int

        var firstAcceleration: Double? { devices.first?.acceleration }
        var firstResolution: Double? { devices.first?.resolution }
        var discoveredDeviceCount: Int { devices.count }
        var deviceNames: [String] { devices.map(\.name) }
    }

    private struct OriginalValues {
        let acceleration: Double
        let accelerationKey: String
        let resolution: Double
    }

    private var eventSystemClient: IOHIDEventSystemClient
    private var originalValues = [String: OriginalValues]()

    init() {
        eventSystemClient = MPCreateHIDEventSystemClient()
    }

    func refreshConnection() {
        eventSystemClient = MPCreateHIDEventSystemClient()
    }

    func readSnapshot() -> Snapshot {
        makeSnapshot(for: currentMouseServices())
    }

    func applyPointerSettings(acceleration: Double, resolution: Double) -> Snapshot {
        applyPointerSettings(
            defaultConfiguration: DeviceConfiguration(
                isEnabled: true,
                acceleration: acceleration,
                resolution: resolution
            ),
            perDeviceConfigurations: [:]
        )
    }

    func applyPointerSettings(
        defaultConfiguration: DeviceConfiguration,
        perDeviceConfigurations: [String: DeviceConfiguration]
    ) -> Snapshot {
        let services = currentMouseServices()
        var accelerationApplyCount = 0
        var resolutionApplyCount = 0

        for service in services {
            let configuration = perDeviceConfigurations[profileIdentifier(for: service)]
                ?? defaultConfiguration
            guard configuration.isEnabled else {
                restoreOriginalValuesIfAvailable(for: service)
                continue
            }

            guard captureOriginalValuesIfNeeded(for: service) else {
                continue
            }
            guard let original = originalValues[serviceID(for: service)] else {
                continue
            }

            guard
                let previousResolution = readFixedProperty(
                    kIOHIDPointerResolutionKey,
                    from: service
                ),
                let previousAcceleration = readFixedProperty(
                    original.accelerationKey,
                    from: service
                )
            else {
                continue
            }

            let desiredResolution = configuration.resolution.clamped(to: 10...1995)
            let desiredAcceleration = configuration.acceleration.clamped(to: 0...40)
            let resolutionNeedsUpdate = !valuesMatch(
                previousResolution,
                desiredResolution,
                tolerance: 0.5
            )
            let accelerationNeedsUpdate = !valuesMatch(
                previousAcceleration,
                desiredAcceleration,
                tolerance: 0.01
            )

            var resolutionWriteSucceeded = true
            if resolutionNeedsUpdate {
                resolutionWriteSucceeded = setFixedProperty(
                    desiredResolution,
                    key: kIOHIDPointerResolutionKey,
                    on: service
                )
                    && readFixedProperty(
                        kIOHIDPointerResolutionKey,
                        from: service
                    ).map {
                        valuesMatch($0, desiredResolution, tolerance: 0.5)
                    } == true
                if !resolutionWriteSucceeded {
                    _ = setFixedProperty(
                        previousResolution,
                        key: kIOHIDPointerResolutionKey,
                        on: service
                    )
                }
            }

            // A successful resolution write needs an acceleration rewrite to
            // rebuild the system filter, even when acceleration itself is unchanged.
            let shouldWriteAcceleration = accelerationNeedsUpdate
                || (resolutionNeedsUpdate && resolutionWriteSucceeded)
            var accelerationWriteSucceeded = true
            if shouldWriteAcceleration {
                accelerationWriteSucceeded = setFixedProperty(
                    desiredAcceleration,
                    key: original.accelerationKey,
                    on: service
                )
                    && readFixedProperty(
                        original.accelerationKey,
                        from: service
                    ).map {
                        valuesMatch($0, desiredAcceleration, tolerance: 0.01)
                    } == true
            }

            if resolutionNeedsUpdate
                && resolutionWriteSucceeded
                && !accelerationWriteSucceeded {
                // Roll back to the state immediately before this transaction,
                // not the state captured when MousePilot first started.
                _ = setFixedProperty(
                    previousResolution,
                    key: kIOHIDPointerResolutionKey,
                    on: service
                )
                _ = setFixedProperty(
                    previousAcceleration,
                    key: original.accelerationKey,
                    on: service
                )
            } else if accelerationNeedsUpdate && !accelerationWriteSucceeded {
                _ = setFixedProperty(
                    previousAcceleration,
                    key: original.accelerationKey,
                    on: service
                )
            }

            if let currentResolution = readFixedProperty(
                kIOHIDPointerResolutionKey,
                from: service
            ), valuesMatch(currentResolution, desiredResolution, tolerance: 0.5) {
                resolutionApplyCount += 1
            }
            if let currentAcceleration = readFixedProperty(
                original.accelerationKey,
                from: service
            ), valuesMatch(currentAcceleration, desiredAcceleration, tolerance: 0.01) {
                accelerationApplyCount += 1
            }
        }

        return makeSnapshot(
            for: services,
            appliedAccelerationDeviceCount: accelerationApplyCount,
            appliedResolutionDeviceCount: resolutionApplyCount
        )
    }

    func applyMouseAcceleration(_ acceleration: Double) -> Snapshot {
        let services = currentMouseServices()
        var accelerationApplyCount = 0

        for service in services {
            guard captureOriginalValuesIfNeeded(for: service) else {
                continue
            }
            guard let original = originalValues[serviceID(for: service)] else {
                continue
            }
            let desiredAcceleration = acceleration.clamped(to: 0...40)
            if let currentAcceleration = readFixedProperty(
                original.accelerationKey,
                from: service
            ), valuesMatch(currentAcceleration, desiredAcceleration, tolerance: 0.01) {
                accelerationApplyCount += 1
                continue
            }
            if setFixedProperty(
                desiredAcceleration,
                key: original.accelerationKey,
                on: service
            ), let currentAcceleration = readFixedProperty(
                original.accelerationKey,
                from: service
            ), valuesMatch(currentAcceleration, desiredAcceleration, tolerance: 0.01) {
                accelerationApplyCount += 1
            }
        }

        return makeSnapshot(for: services, appliedAccelerationDeviceCount: accelerationApplyCount)
    }

    func restoreOriginalPointerSettings() -> Snapshot {
        let services = currentMouseServices()
        var accelerationApplyCount = 0
        var resolutionApplyCount = 0
        var restoredDeviceIDs = Set<String>()

        for service in services {
            let id = serviceID(for: service)
            guard let original = originalValues[id] else {
                continue
            }

            let restoredResolution = setFixedPropertyAndVerify(
                original.resolution,
                key: kIOHIDPointerResolutionKey,
                on: service,
                tolerance: 0.5
            )
            if restoredResolution {
                resolutionApplyCount += 1
            }

            let restoredAcceleration = setFixedPropertyAndVerify(
                original.acceleration,
                key: original.accelerationKey,
                on: service,
                tolerance: 0.01
            )
            if restoredAcceleration {
                accelerationApplyCount += 1
            }

            if restoredResolution && restoredAcceleration {
                restoredDeviceIDs.insert(id)
            }
        }

        let snapshot = makeSnapshot(
            for: services,
            appliedAccelerationDeviceCount: accelerationApplyCount,
            appliedResolutionDeviceCount: resolutionApplyCount
        )
        restoredDeviceIDs.forEach { originalValues.removeValue(forKey: $0) }
        return snapshot
    }

    private func makeSnapshot(
        for services: [IOHIDServiceClient],
        appliedAccelerationDeviceCount: Int = 0,
        appliedResolutionDeviceCount: Int = 0
    ) -> Snapshot {
        let states = services.map { service in
            let id = serviceID(for: service)
            let accelerationProperty = originalValues[id]?.accelerationKey
                ?? accelerationKey(for: service)
            return DeviceState(
                id: id,
                profileIdentifier: profileIdentifier(for: service),
                name: deviceName(for: service),
                acceleration: readFixedProperty(accelerationProperty, from: service),
                resolution: readFixedProperty(kIOHIDPointerResolutionKey, from: service)
            )
        }
        let firstOriginal = states.first.flatMap { originalValues[$0.id] }

        return Snapshot(
            devices: states,
            originalFirstAcceleration: firstOriginal?.acceleration,
            originalFirstResolution: firstOriginal?.resolution,
            appliedAccelerationDeviceCount: appliedAccelerationDeviceCount,
            appliedResolutionDeviceCount: appliedResolutionDeviceCount
        )
    }

    private func currentMouseServices() -> [IOHIDServiceClient] {
        guard let copiedServices = IOHIDEventSystemClientCopyServices(eventSystemClient) else {
            return []
        }

        // The API contract guarantees that this CFArray contains IOHIDServiceClient values.
        let services = copiedServices as NSArray as! [IOHIDServiceClient]
        return services
            .filter(isExternalMouseService)
            .sorted { serviceID(for: $0) < serviceID(for: $1) }
    }

    private func isExternalMouseService(_ service: IOHIDServiceClient) -> Bool {
        let isMouse = IOHIDServiceClientConformsTo(
            service,
            UInt32(kHIDPage_GenericDesktop),
            UInt32(kHIDUsage_GD_Mouse)
        ) != 0
        guard isMouse else {
            return false
        }

        return ExternalMouseEligibility.isSupported(
            name: deviceName(for: service),
            transport: stringProperty(kIOHIDTransportKey, from: service),
            isBuiltIn: (integerProperty(kIOHIDBuiltInKey, from: service) ?? 0) != 0,
            pointerAccelerationType: stringProperty(
                kIOHIDPointerAccelerationTypeKey,
                from: service
            )
        )
    }

    private func captureOriginalValuesIfNeeded(for service: IOHIDServiceClient) -> Bool {
        let id = serviceID(for: service)
        if originalValues[id] != nil {
            return true
        }

        let accelerationKey = accelerationKey(for: service)
        guard
            let acceleration = readFixedProperty(accelerationKey, from: service),
            acceleration.isFinite,
            let resolution = readFixedProperty(kIOHIDPointerResolutionKey, from: service),
            resolution.isFinite,
            resolution > 0
        else {
            return false
        }

        originalValues[id] = OriginalValues(
            acceleration: acceleration,
            accelerationKey: accelerationKey,
            resolution: resolution
        )
        return true
    }

    private func restoreOriginalValuesIfAvailable(for service: IOHIDServiceClient) {
        let id = serviceID(for: service)
        guard let original = originalValues[id] else {
            return
        }

        let restoredResolution = setFixedPropertyAndVerify(
            original.resolution,
            key: kIOHIDPointerResolutionKey,
            on: service,
            tolerance: 0.5
        )
        let restoredAcceleration = setFixedPropertyAndVerify(
            original.acceleration,
            key: original.accelerationKey,
            on: service,
            tolerance: 0.01
        )
        if restoredResolution && restoredAcceleration {
            originalValues.removeValue(forKey: id)
        }
    }

    private func accelerationKey(for service: IOHIDServiceClient) -> String {
        if let key = stringProperty(kIOHIDPointerAccelerationTypeKey, from: service), !key.isEmpty {
            return key
        }

        if readFixedProperty(kIOHIDPointerAccelerationKey, from: service) != nil {
            return kIOHIDPointerAccelerationKey
        }

        return kIOHIDMouseAccelerationType as String
    }

    private func readFixedProperty(_ key: String, from service: IOHIDServiceClient) -> Double? {
        guard let number = IOHIDServiceClientCopyProperty(service, key as NSString) as? NSNumber else {
            return nil
        }

        return number.doubleValue / 65_536.0
    }

    private func stringProperty(_ key: String, from service: IOHIDServiceClient) -> String? {
        IOHIDServiceClientCopyProperty(service, key as NSString) as? String
    }

    private func integerProperty(_ key: String, from service: IOHIDServiceClient) -> Int? {
        (IOHIDServiceClientCopyProperty(service, key as NSString) as? NSNumber)?.intValue
    }

    private func setFixedProperty(_ value: Double, key: String, on service: IOHIDServiceClient) -> Bool {
        guard value.isFinite else {
            return false
        }
        let roundedFixedValue = (value * 65_536.0).rounded()
        guard roundedFixedValue.isFinite,
              roundedFixedValue >= Double(Int32.min),
              roundedFixedValue <= Double(Int32.max) else {
            return false
        }
        let fixedValue = Int32(roundedFixedValue)
        return IOHIDServiceClientSetProperty(service, key as NSString, NSNumber(value: fixedValue))
    }

    private func setFixedPropertyAndVerify(
        _ value: Double,
        key: String,
        on service: IOHIDServiceClient,
        tolerance: Double
    ) -> Bool {
        _ = setFixedProperty(value, key: key, on: service)
        return readFixedProperty(key, from: service).map {
            valuesMatch($0, value, tolerance: tolerance)
        } == true
    }

    private func valuesMatch(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double
    ) -> Bool {
        lhs.isFinite && rhs.isFinite && abs(lhs - rhs) <= tolerance
    }

    private func serviceID(for service: IOHIDServiceClient) -> String {
        if let registryID = IOHIDServiceClientGetRegistryID(service) as? NSNumber {
            return registryID.stringValue
        }

        let vendorID = integerProperty(kIOHIDVendorIDKey, from: service) ?? 0
        let productID = integerProperty(kIOHIDProductIDKey, from: service) ?? 0
        return "\(vendorID):\(productID):\(deviceName(for: service))"
    }

    private func profileIdentifier(for service: IOHIDServiceClient) -> String {
        MouseDeviceIdentity.identifier(
            vendorID: integerProperty(kIOHIDVendorIDKey, from: service) ?? 0,
            productID: integerProperty(kIOHIDProductIDKey, from: service) ?? 0,
            serialNumber: stringProperty(kIOHIDSerialNumberKey, from: service),
            transport: stringProperty(kIOHIDTransportKey, from: service),
            locationID: integerProperty(kIOHIDLocationIDKey, from: service),
            name: deviceName(for: service)
        )
    }

    private func deviceName(for service: IOHIDServiceClient) -> String {
        if let name = stringProperty(kIOHIDProductKey, from: service), !name.isEmpty {
            return name
        }

        let vendorID = integerProperty(kIOHIDVendorIDKey, from: service) ?? 0
        let productID = integerProperty(kIOHIDProductIDKey, from: service) ?? 0
        return String(format: "Mouse %04X:%04X", vendorID, productID)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
