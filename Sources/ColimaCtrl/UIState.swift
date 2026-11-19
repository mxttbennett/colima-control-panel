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

enum ContainerSort: String, CaseIterable, Identifiable {
    case name = "Name", cpu = "CPU", memory = "Memory", uptime = "Uptime"
    var id: String { rawValue }
}

struct ConfirmRequest {
    let title: String
    let message: String
    let button: String
    let action: @MainActor () -> Void
}

@MainActor @Observable
final class UIState {
    static let multiSelection = "multi-selection"

    var section: Section = .containers
    var selectedContainerID: String?
    var selectedContainerIDs: Set<String> = []
    var selectedVolumeID: String?
    var selectedImageID: String?
    var selectedNetworkID: String?
    var detailTab: DetailTab = .info
    var filter = ""
    var runningOnly = false
    var containerSort: ContainerSort { didSet { UserDefaults.standard.set(containerSort.rawValue, forKey: "containerSort") } }
    var showPalette = false
    var showSetup = false
    var confirm: ConfirmRequest?
    /// Container name from `-select`, applied once the container list loads.
    var pendingSelection: String?

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "section"), let section = Section(rawValue: raw) { self.section = section }
        if let raw = defaults.string(forKey: "tab"), let tab = DetailTab(rawValue: raw.capitalized) { detailTab = tab }
        pendingSelection = defaults.string(forKey: "select")
        containerSort = defaults.string(forKey: "containerSort").flatMap(ContainerSort.init(rawValue:)) ?? .name
    }

    /// The row whose detail panel is open in the current section.
    var paneSelection: String? {
        get {
            switch section {
            case .containers: selectedContainerIDs.count > 1 ? Self.multiSelection : selectedContainerID
            case .volumes: selectedVolumeID
            case .images: selectedImageID
            case .networks: selectedNetworkID
            case .system: nil
            }
        }
        set {
            switch section {
            case .containers:
                selectedContainerID = newValue
                if newValue == nil { selectedContainerIDs = [] }
            case .volumes: selectedVolumeID = newValue
            case .images: selectedImageID = newValue
            case .networks: selectedNetworkID = newValue
            case .system: break
            }
        }
    }

    func closePane() { paneSelection = nil }

    func show(_ container: String, tab: DetailTab = .info) {
        section = .containers
        selectedContainerID = container
        selectedContainerIDs = [container]
        detailTab = tab
    }
}

@MainActor @Observable
final class Preferences {
    var dockBadge: Bool { didSet { UserDefaults.standard.set(dockBadge, forKey: "dockBadge") } }
    var showMenuBarIcon: Bool { didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    var menuBarCount: Bool { didSet { UserDefaults.standard.set(menuBarCount, forKey: "menuBarCount") } }
    var setupCompleted: Bool { didSet { UserDefaults.standard.set(setupCompleted, forKey: "setupCompleted") } }
    var statsSeconds: Int { didSet { UserDefaults.standard.set(statsSeconds, forKey: "statsSeconds") } }
    var keepCCPWithColima: Bool { didSet { UserDefaults.standard.set(keepCCPWithColima, forKey: "keepCCPWithColima") } }
    var notifyOnFailures: Bool { didSet { UserDefaults.standard.set(notifyOnFailures, forKey: "notifyOnFailures") } }
    var logCapacity: Int { didSet { UserDefaults.standard.set(logCapacity, forKey: "logCapacity") } }
    var defaultDetailTab: DetailTab { didSet { UserDefaults.standard.set(defaultDetailTab.rawValue, forKey: "defaultDetailTab") } }
    var colimaWatcherError: String?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["dockBadge": false, "showMenuBarIcon": true, "menuBarCount": false, "setupCompleted": false, "statsSeconds": 3, "keepCCPWithColima": false, "notifyOnFailures": true, "logCapacity": LogModel.defaultCapacity, "defaultDetailTab": DetailTab.info.rawValue])
        dockBadge = defaults.bool(forKey: "dockBadge")
        showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        menuBarCount = defaults.bool(forKey: "menuBarCount")
        setupCompleted = defaults.bool(forKey: "setupCompleted")
        statsSeconds = defaults.integer(forKey: "statsSeconds")
        keepCCPWithColima = defaults.bool(forKey: "keepCCPWithColima")
        notifyOnFailures = defaults.bool(forKey: "notifyOnFailures")
        logCapacity = defaults.integer(forKey: "logCapacity")
        defaultDetailTab = defaults.string(forKey: "defaultDetailTab").flatMap(DetailTab.init(rawValue:)) ?? .info
    }
}
