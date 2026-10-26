import Foundation
import Observation
import ColimaCtrlCore

enum Section: String, CaseIterable, Identifiable {
    case containers, volumes, images, networks, system

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .containers: "shippingbox"
        case .volumes: "cylinder"
        case .images: "square.stack.3d.up"
        case .networks: "point.3.connected.trianglepath.dotted"
        case .system: "waveform.path.ecg"
        }
    }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case info = "Info", logs = "Logs"
    var id: String { rawValue }
}

@MainActor @Observable
final class UIState {
    var section: Section = .containers
    var selectedContainerID: String?
    var detailTab: DetailTab = .info
    var filter = ""
    var runningOnly = false
    var showPalette = false
    /// Container name from `-select`, applied once the container list loads.
    var pendingSelection: String?

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "section"), let section = Section(rawValue: raw) { self.section = section }
        if let raw = defaults.string(forKey: "tab"), let tab = DetailTab(rawValue: raw.capitalized) { detailTab = tab }
        pendingSelection = defaults.string(forKey: "select")
    }

    func toggleSelection(_ id: String) {
        selectedContainerID = selectedContainerID == id ? nil : id
        detailTab = .info
    }

    func show(_ container: String, tab: DetailTab = .info) {
        section = .containers
        selectedContainerID = container
        detailTab = tab
    }
}

@MainActor @Observable
final class Preferences {
    var dockBadge: Bool { didSet { UserDefaults.standard.set(dockBadge, forKey: "dockBadge") } }
    var menuBarCount: Bool { didSet { UserDefaults.standard.set(menuBarCount, forKey: "menuBarCount") } }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["dockBadge": true, "menuBarCount": false])
        dockBadge = defaults.bool(forKey: "dockBadge")
        menuBarCount = defaults.bool(forKey: "menuBarCount")
    }
}
