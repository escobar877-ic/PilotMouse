import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class AutoScrollController {
    private static let frameInterval: TimeInterval = 1.0 / 60.0
    private static let deadZone: CGFloat = 12
    private static let maximumDeltaPerFrame = 48.0

    private(set) var isActive = false

    private var anchor = CGPoint.zero
    private var direction: ScrollDirection = .natural
    private var timer: Timer?
    private var indicatorPanel: NSPanel?
    private var verticalRemainder = 0.0
    private var horizontalRemainder = 0.0

    @discardableResult
    func toggle(direction: ScrollDirection) -> Bool {
        if isActive {
            stop()
            return true
        }

        return start(direction: direction)
    }

    @discardableResult
    func start(direction: ScrollDirection) -> Bool {
        guard let cursorEvent = CGEvent(source: nil) else {
            return false
        }

        stop()
        anchor = cursorEvent.location
        self.direction = direction
        verticalRemainder = 0
        horizontalRemainder = 0
        showIndicator(at: NSEvent.mouseLocation)

        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        isActive = true
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        indicatorPanel?.orderOut(nil)
        verticalRemainder = 0
        horizontalRemainder = 0
        isActive = false
    }

    private func tick() {
        guard isActive, let cursorEvent = CGEvent(source: nil) else {
            stop()
            return
        }

        let cursor = cursorEvent.location
        var horizontalVelocity = velocity(for: cursor.x - anchor.x)
        var verticalVelocity = velocity(for: cursor.y - anchor.y)
        let modifierFlags = CGEventSource.flagsState(.combinedSessionState)
        if modifierFlags.contains(.maskShift) {
            if abs(horizontalVelocity) > abs(verticalVelocity) {
                verticalVelocity = 0
            } else {
                horizontalVelocity = 0
            }
        }
        let directionMultiplier = direction == .reversed ? -1.0 : 1.0

        // Quartz uses positive wheel deltas for up and left. Cursor displacement uses right and down.
        let requestedVertical = -verticalVelocity * directionMultiplier + verticalRemainder
        let requestedHorizontal = -horizontalVelocity * directionMultiplier + horizontalRemainder
        let vertical = requestedVertical.rounded(.towardZero)
        let horizontal = requestedHorizontal.rounded(.towardZero)
        verticalRemainder = requestedVertical - vertical
        horizontalRemainder = requestedHorizontal - horizontal

        guard vertical != 0 || horizontal != 0 else {
            return
        }

        postScroll(
            vertical: Int32(vertical),
            horizontal: Int32(horizontal),
            modifierFlags: modifierFlags
        )
    }

    private func velocity(for displacement: CGFloat) -> Double {
        let magnitude = abs(displacement)
        guard magnitude > Self.deadZone else {
            return 0
        }

        let distance = Double(magnitude - Self.deadZone)
        let accelerated = pow(distance / 10.0, 1.35) * 1.2
        return min(accelerated, Self.maximumDeltaPerFrame) * (displacement < 0 ? -1 : 1)
    }

    private func postScroll(
        vertical: Int32,
        horizontal: Int32,
        modifierFlags: CGEventFlags
    ) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else {
            stop()
            return
        }

        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.flags = modifierFlags
        MousePilotSyntheticEvent.mark(event)
        event.post(tap: .cghidEventTap)
    }

    private func showIndicator(at location: NSPoint) {
        let panel = indicatorPanel ?? makeIndicatorPanel()
        indicatorPanel = panel
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(x: location.x - size.width / 2, y: location.y - size.height / 2)
        )
        panel.orderFrontRegardless()
    }

    private func makeIndicatorPanel() -> NSPanel {
        let size = NSSize(width: 36, height: 36)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: AutoScrollIndicatorView())
        return panel
    }
}

private struct AutoScrollIndicatorView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
            Circle()
                .stroke(Color.primary.opacity(0.28), lineWidth: 1)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(2)
        .frame(width: 36, height: 36)
    }
}
