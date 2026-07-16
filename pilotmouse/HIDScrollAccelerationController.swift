import Foundation
import IOKit.hid
import IOKit.hidsystem

final class HIDScrollAccelerationController {
    struct DeviceState {
        let id: String
        let profileIdentifier: String
        let name: String
        let acceleration: Double?
        let resolution: Double?
        let originalResolution: Double?
    }

    struct DeviceConfiguration: Equatable {
        let isEnabled: Bool
        let acceleration: Double
        let sensitivityFactor: Double

        static let disabled = DeviceConfiguration(
            isEnabled: false,
            acceleration: -1,
            sensitivityFactor: 0
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

    private struct OriginalValue {
        let acceleration: Double
        let accelerationKey: String
        let resolutions: [String: Double]
        let primaryResolutionKey: String

        var primaryResolution: Double {
            resolutions[primaryResolutionKey]!
        }
    }

    private var eventSystemClient: IOHIDEventSystemClient
    private var originalValues = [String: OriginalValue]()

    init() {
        eventSystemClient = MPCreateHIDEventSystemClient()
    }

    func refreshConnection() {
        eventSystemClient = MPCreateHIDEventSystemClient()
    }

    func readSnapshot() -> Snapshot {
        makeSnapshot(for: currentMouseServices())
    }

    func applyScrollSettings(acceleration: Double, sensitivityFactor: Double) -> Snapshot {
        applyScrollSettings(
            defaultConfiguration: DeviceConfiguration(
                isEnabled: true,
                acceleration: acceleration,
                sensitivityFactor: sensitivityFactor
            ),
            perDeviceConfigurations: [:]
        )
    }

    func applyScrollSettings(
        defaultConfiguration: DeviceConfiguration,
        perDeviceConfigurations: [String: DeviceConfiguration]
    ) -> Snapshot {
        let services = currentMouseServices()
        var appliedAccelerationDeviceCount = 0
        var appliedResolutionDeviceCount = 0

        for service in services {
            let configuration = perDeviceConfigurations[profileIdentifier(for: service)]
                ?? defaultConfiguration
            guard configuration.isEnabled else {
                restoreOriginalValueIfAvailable(for: service)
                continue
            }

            guard captureOriginalValueIfNeeded(for: service) else {
                continue
            }
            let id = serviceID(for: service)
            guard let original = originalValues[id] else {
                continue
            }

            let previousResolutions = Dictionary(
                uniqueKeysWithValues: original.resolutions.keys.compactMap { key in
                    readFixedProperty(key, from: service).map { (key, $0) }
                }
            )
            guard previousResolutions.count == original.resolutions.count,
                  let previousAcceleration = readFixedProperty(
                    original.accelerationKey,
                    from: service
                  ) else {
                continue
            }

            let desiredResolutions = original.resolutions.mapValues { baseResolution in
                ScrollSensitivityMapper.resolution(
                    forBaseResolution: baseResolution,
                    factor: configuration.sensitivityFactor
                )
            }
            let desiredAcceleration = configuration.acceleration.clamped(to: -1...20)
            let resolutionNeedsUpdate = desiredResolutions.contains { key, desired in
                guard let previous = previousResolutions[key] else { return true }
                return !valuesMatch(previous, desired, tolerance: 0.01)
            }
            let accelerationNeedsUpdate = !valuesMatch(
                previousAcceleration,
                desiredAcceleration,
                tolerance: 0.001
            )

            var resolutionWriteSucceeded = true
            if resolutionNeedsUpdate {
                for (key, desired) in desiredResolutions {
                    guard let previous = previousResolutions[key],
                          !valuesMatch(previous, desired, tolerance: 0.01) else {
                        continue
                    }
                    if !setFixedProperty(desired, key: key, on: service)
                        || readFixedProperty(key, from: service).map({
                            valuesMatch($0, desired, tolerance: 0.01)
                        }) != true {
                        resolutionWriteSucceeded = false
                        break
                    }
                }
                if !resolutionWriteSucceeded {
                    _ = setResolutions(previousResolutions, on: service)
                }
            }

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
                        valuesMatch($0, desiredAcceleration, tolerance: 0.001)
                    } == true
            }

            if resolutionNeedsUpdate
                && resolutionWriteSucceeded
                && !accelerationWriteSucceeded {
                _ = setResolutions(previousResolutions, on: service)
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

            let currentResolutions = Dictionary(
                uniqueKeysWithValues: desiredResolutions.keys.compactMap { key in
                    readFixedProperty(key, from: service).map { (key, $0) }
                }
            )
            if currentResolutions.count == desiredResolutions.count,
               desiredResolutions.allSatisfy({ key, desired in
                   currentResolutions[key].map {
                       valuesMatch($0, desired, tolerance: 0.01)
                   } == true
               }) {
                appliedResolutionDeviceCount += 1
            }
            if let currentAcceleration = readFixedProperty(
                original.accelerationKey,
                from: service
            ), valuesMatch(
                currentAcceleration,
                desiredAcceleration,
                tolerance: 0.001
            ) {
                appliedAccelerationDeviceCount += 1
            }
        }

        return makeSnapshot(
            for: services,
            appliedAccelerationDeviceCount: appliedAccelerationDeviceCount,
            appliedResolutionDeviceCount: appliedResolutionDeviceCount
        )
    }

    func restoreOriginalScrollSettings() -> Snapshot {
        let services = currentMouseServices()
        var appliedAccelerationDeviceCount = 0
        var appliedResolutionDeviceCount = 0
        var restoredDeviceIDs = Set<String>()

        for service in services {
            let id = serviceID(for: service)
            guard let original = originalValues[id] else {
                continue
            }

            let restoredResolution = restoreResolutions(original, on: service)
            if restoredResolution {
                appliedResolutionDeviceCount += 1
            }

            let restoredAcceleration = setFixedPropertyAndVerify(
                original.acceleration,
                key: original.accelerationKey,
                on: service,
                tolerance: 0.001
            )
            if restoredAcceleration {
                appliedAccelerationDeviceCount += 1
            }

            if restoredResolution && restoredAcceleration {
                restoredDeviceIDs.insert(id)
            }
        }

        let snapshot = makeSnapshot(
            for: services,
            appliedAccelerationDeviceCount: appliedAccelerationDeviceCount,
            appliedResolutionDeviceCount: appliedResolutionDeviceCount
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
            let original = originalValues[id]
            let primaryResolutionKey = original?.primaryResolutionKey
                ?? preferredResolutionProperty(for: service)?.key
            return DeviceState(
                id: id,
                profileIdentifier: profileIdentifier(for: service),
                name: deviceName(for: service),
                acceleration: readFixedProperty(
                    original?.accelerationKey ?? accelerationKey(for: service),
                    from: service
                ),
                resolution: primaryResolutionKey.flatMap {
                    readFixedProperty($0, from: service)
                },
                originalResolution: original?.primaryResolution
            )
        }
        let firstOriginal = states.first.flatMap { originalValues[$0.id] }

        return Snapshot(
            devices: states,
            originalFirstAcceleration: firstOriginal?.acceleration,
            originalFirstResolution: firstOriginal?.primaryResolution,
            appliedAccelerationDeviceCount: appliedAccelerationDeviceCount,
            appliedResolutionDeviceCount: appliedResolutionDeviceCount
        )
    }

    private func currentMouseServices() -> [IOHIDServiceClient] {
        guard let copiedServices = IOHIDEventSystemClientCopyServices(eventSystemClient) else {
            return []
        }

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

    private func captureOriginalValueIfNeeded(for service: IOHIDServiceClient) -> Bool {
        let id = serviceID(for: service)
        if originalValues[id] != nil {
            return true
        }

        let key = accelerationKey(for: service)
        guard
            let acceleration = readFixedProperty(key, from: service),
            acceleration.isFinite,
            let resolutionProperties = resolutionProperties(for: service),
            let primaryResolutionKey = preferredResolutionKey(
                in: resolutionProperties
            )
        else {
            return false
        }

        originalValues[id] = OriginalValue(
            acceleration: acceleration,
            accelerationKey: key,
            resolutions: resolutionProperties,
            primaryResolutionKey: primaryResolutionKey
        )
        return true
    }

    private func restoreOriginalValueIfAvailable(for service: IOHIDServiceClient) {
        let id = serviceID(for: service)
        guard let original = originalValues[id] else {
            return
        }

        let restoredResolution = restoreResolutions(original, on: service)
        let restoredAcceleration = setFixedPropertyAndVerify(
            original.acceleration,
            key: original.accelerationKey,
            on: service,
            tolerance: 0.001
        )
        if restoredResolution && restoredAcceleration {
            originalValues.removeValue(forKey: id)
        }
    }

    @discardableResult
    private func restoreResolutions(
        _ original: OriginalValue,
        on service: IOHIDServiceClient
    ) -> Bool {
        setResolutions(original.resolutions, on: service)
    }

    @discardableResult
    private func setResolutions(
        _ resolutions: [String: Double],
        on service: IOHIDServiceClient
    ) -> Bool {
        var restoredAll = true
        for (key, resolution) in resolutions {
            if !setFixedPropertyAndVerify(
                resolution,
                key: key,
                on: service,
                tolerance: 0.01
            ) {
                restoredAll = false
            }
        }
        return restoredAll
    }

    private func resolutionProperties(
        for service: IOHIDServiceClient
    ) -> [String: Double]? {
        let keys = [
            kIOHIDScrollResolutionXKey,
            kIOHIDScrollResolutionYKey,
            kIOHIDScrollResolutionZKey,
            kIOHIDScrollResolutionKey
        ]
        var result = [String: Double]()
        for key in keys {
            guard let value = readFixedProperty(key, from: service),
                  value.isFinite,
                  value > 0 else {
                continue
            }
            result[key] = value
        }
        return result.isEmpty ? nil : result
    }

    private func preferredResolutionProperty(
        for service: IOHIDServiceClient
    ) -> (key: String, value: Double)? {
        guard let properties = resolutionProperties(for: service),
              let key = preferredResolutionKey(in: properties),
              let value = properties[key] else {
            return nil
        }
        return (key, value)
    }

    private func preferredResolutionKey(
        in properties: [String: Double]
    ) -> String? {
        [
            kIOHIDScrollResolutionYKey,
            kIOHIDScrollResolutionKey,
            kIOHIDScrollResolutionXKey,
            kIOHIDScrollResolutionZKey
        ].first(where: { properties[$0] != nil })
    }

    private func accelerationKey(for service: IOHIDServiceClient) -> String {
        if let key = stringProperty(kIOHIDScrollAccelerationTypeKey, from: service), !key.isEmpty {
            return key
        }

        if readFixedProperty(kIOHIDMouseScrollAccelerationKey, from: service) != nil {
            return kIOHIDMouseScrollAccelerationKey
        }

        return kIOHIDScrollAccelerationKey
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
