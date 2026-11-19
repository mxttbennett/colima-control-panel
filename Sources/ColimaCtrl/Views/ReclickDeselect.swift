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

/// Watches mouse events from the window and, when a plain click lands on the only selected row of the neighboring table,
/// deselects that row once the button comes up. Reading the selection on mouse down is what tells a re-click from a new click.
final class ReclickAnchor: NSView {
    private var monitor: Any?
    private var armed: (table: NSTableView, row: Int)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.handle(event)
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

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window, let table = neighboringTable() else { return }
        let point = table.convert(event.locationInWindow, from: nil)
        switch event.type {
        case .leftMouseDown:
            armed = nil
            let plain = event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty
            guard plain, event.clickCount == 1, table.bounds.contains(point), table.selectedRowIndexes.count == 1 else { return }
            let row = table.row(at: point)
            guard row >= 0, table.isRowSelected(row), !Self.hitsControl(table, event) else { return }
            armed = (table, row)
        case .leftMouseUp:
            defer { armed = nil }
            guard let armed, armed.table === table, table.row(at: point) == armed.row, table.isRowSelected(armed.row) else { return }
            DispatchQueue.main.async { table.deselectRow(armed.row) }
        default:
            break
        }
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
