// Drives the real ReclickDeselect code against an NSTableView with synthesized mouse events.
// The pointer is warped to each click point, because the release check reads the real pointer position.
import AppKit

final class Source: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { 5 }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { NSView() }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
let scroll = NSScrollView(frame: container.bounds)
let table = NSTableView()
let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
column.width = 380
table.addTableColumn(column)
table.headerView = nil
let source = Source()
table.dataSource = source
table.delegate = source
scroll.documentView = table
container.addSubview(scroll)
container.addSubview(ReclickAnchor(frame: .zero))
window.contentView = container
app.activate(ignoringOtherApps: true)
window.makeKeyAndOrderFront(nil)
app.finishLaunching()
RunLoop.main.run(until: Date().addingTimeInterval(0.3))

var eventNumber = 1
func click(row: Int, modifiers: NSEvent.ModifierFlags = []) {
    let rect = table.rect(ofRow: row)
    let point = table.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
    let screen = window.convertPoint(toScreen: point)
    CGWarpMouseCursorPosition(CGPoint(x: screen.x, y: NSScreen.screens[0].frame.height - screen.y))
    func event(_ type: NSEvent.EventType) -> NSEvent {
        eventNumber += 1
        return NSEvent.mouseEvent(with: type, location: point, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: eventNumber, clickCount: 1, pressure: 1)!
    }
    NSApp.postEvent(event(.leftMouseUp), atStart: false)
    NSApp.sendEvent(event(.leftMouseDown))
    RunLoop.main.run(until: Date().addingTimeInterval(0.4))
}

var failures = 0
func check(_ label: String, _ passed: Bool) {
    print(passed ? "ok  " : "FAIL", label, Array(table.selectedRowIndexes))
    if !passed { failures += 1 }
}

table.selectRowIndexes([1], byExtendingSelection: false)
click(row: 1)
check("clicking the only selected row clears it", table.selectedRowIndexes.isEmpty)

table.selectRowIndexes([1], byExtendingSelection: false)
click(row: 2)
check("clicking a different row does not clear the selection", !table.selectedRowIndexes.isEmpty)

table.selectRowIndexes([1], byExtendingSelection: false)
click(row: 1, modifiers: .command)
check("a command-click is left to the table", table.selectedRowIndexes == [1])

table.selectRowIndexes([1, 2], byExtendingSelection: false)
click(row: 1)
check("clicking inside a multi-selection does not clear it", !table.selectedRowIndexes.isEmpty)

exit(failures == 0 ? 0 : 1)
