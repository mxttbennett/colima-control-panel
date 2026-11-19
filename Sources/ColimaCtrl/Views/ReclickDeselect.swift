import AppKit
import SwiftUI

extension View {
    /// Clicking the one selected row of a list or table again clears the selection.
    func deselectsOnReclick() -> some View {
        background(ReclickDeselect())
    }
}

private struct ReclickDeselect: NSViewRepresentable {
    func makeNSView(context: Context) -> ReclickAnchor { ReclickAnchor() }
    func updateNSView(_ view: ReclickAnchor, context: Context) {}
}

/// Watches mouse-downs from the window and, when a plain click lands on the only selected row of the neighboring table,
/// deselects that row once the button is released. A table runs its own loop from mouse down to mouse up, so the release is
/// found by polling the button state rather than through an event.
final class ReclickAnchor: NSView {
    private var monitor: Any?
    private var timer: Timer?
    private var armed: (table: NSTableView, row: Int, down: NSPoint)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        disarm()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.armIfReclick(event)
            return event
        }
    }

    private func neighboringTable() -> NSTableView? {
        var ancestor: NSView? = superview
        for _ in 0..<6 {
            guard let current = ancestor else { return nil }
            if let table = Self.firstTable(in: current) { return table }
            ancestor = current.superview
        }
        return nil
    }

    private static func firstTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for child in view.subviews { if let found = firstTable(in: child) { return found } }
        return nil
    }

    private func disarm() {
        timer?.invalidate()
        timer = nil
        armed = nil
    }

    private func armIfReclick(_ event: NSEvent) {
        disarm()
        guard let window, event.window === window, let table = neighboringTable() else { return }
        let point = table.convert(event.locationInWindow, from: nil)
        let plain = event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty
        guard plain, event.clickCount == 1, table.bounds.contains(point), table.selectedRowIndexes.count == 1 else { return }
        let row = table.row(at: point)
        guard row >= 0, table.isRowSelected(row), !Self.hitsControl(table, event) else { return }
        armed = (table, row, point)
        let started = Date()
        let poll = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else { return }
            if NSEvent.pressedMouseButtons & 1 != 0, Date().timeIntervalSince(started) < 10 { return }
            self.released()
        }
        RunLoop.main.add(poll, forMode: .common)
        timer = poll
    }

    private func released() {
        defer { disarm() }
        guard let window, let (table, row, down) = armed else { return }
        let up = table.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard hypot(up.x - down.x, up.y - down.y) < 5, table.row(at: up) == row, table.selectedRowIndexes == [row] else { return }
        table.deselectRow(row)
    }

    private static func hitsControl(_ table: NSTableView, _ event: NSEvent) -> Bool {
        var view = table.window?.contentView?.hitTest(event.locationInWindow)
        while let current = view, current !== table {
            if current is NSControl { return true }
            view = current.superview
        }
        return false
    }
}
