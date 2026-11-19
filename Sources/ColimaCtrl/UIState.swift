import Foundation
import Observation
import SwiftUI
import ColimaCtrlCore

enum Section: String, CaseIterable, Identifiable {
    case containers, volumes, images, networks, system, activity

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// The digit that jumps here with ⌘.
    var shortcut: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    var symbol: String {
        switch self {
        case .containers: "shippingbox"
        case .volumes: "cylinder"
        case .images: "square.stack.3d.up"
        case .networks: "point.3.connected.trianglepath.dotted"
        case .system: "waveform.path.ecg"
        case .activity: "clock.arrow.circlepath"
        }
    }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case info = "Info", logs = "Logs"
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

    var section: Section = .containers { didSet { UserDefaults.standard.set(section.rawValue, forKey: "section") } }
    var selectedContainerID: String?
    var selectedContainerIDs: Set<String> = []
    var selectedVolumeIDs: Set<String> = []
    var selectedImageIDs: Set<String> = []
    var selectedNetworkIDs: Set<String> = []
    var detailTab: DetailTab = .info
    var filter = ""
    var runningOnly = false
    var activityFailuresOnly = false
    /// Newest Activity event id the user has looked at, so the sidebar can flag later failures.
    var seenActivityID = -1
    var containerSort: ContainerSort { didSet { UserDefaults.standard.set(containerSort.rawValue, forKey: "containerSort") } }
    var showPalette = false
    var pendingUpdateCheck = false
    var showSetup = false
    var showPull = false
    var focusFilter = 0
    var zoom: Double = 1 { didSet { UserDefaults.standard.set(zoom, forKey: "zoom") } }
    var logFilter = ""
    var confirm: ConfirmRequest?
    /// Container name from `-select`, applied once the container list loads.
    var pendingSelection: String?

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "section"), let section = Section(rawValue: raw) { self.section = section }
        if let raw = defaults.string(forKey: "tab"), let tab = DetailTab(rawValue: raw.capitalized) { detailTab = tab }
        pendingSelection = defaults.string(forKey: "select")
        let savedZoom = defaults.double(forKey: "zoom")
        if savedZoom > 0 { zoom = Zoom.step(savedZoom, by: 0) }
        containerSort = defaults.string(forKey: "containerSort").flatMap(ContainerSort.init(rawValue:)) ?? .name
    }

    /// The row whose detail panel is open in the current section.
    var paneSelection: String? {
        get {
            switch section {
            case .containers: selectedContainerIDs.count > 1 ? Self.multiSelection : selectedContainerID
            case .volumes: Self.pane(for: selectedVolumeIDs)
            case .images: Self.pane(for: selectedImageIDs)
            case .networks: Self.pane(for: selectedNetworkIDs)
            case .system, .activity: nil
            }
        }
        set {
            switch section {
            case .containers:
                selectedContainerID = newValue
                if newValue == nil { selectedContainerIDs = [] }
            case .volumes: selectedVolumeIDs = newValue.map { [$0] } ?? []
            case .images: selectedImageIDs = newValue.map { [$0] } ?? []
            case .networks: selectedNetworkIDs = newValue.map { [$0] } ?? []
            case .system, .activity: break
            }
        }
    }

    func zoomIn() { zoom = Zoom.step(zoom, by: 1) }
    func zoomOut() { zoom = Zoom.step(zoom, by: -1) }
    func resetZoom() { zoom = 1 }

    func closePane() { paneSelection = nil }

    private static func pane(for ids: Set<String>) -> String? { ids.count > 1 ? multiSelection : ids.first }

    func resetSelection() {
        selectedContainerID = nil
        selectedContainerIDs = []
        selectedVolumeIDs = []
        selectedImageIDs = []
        selectedNetworkIDs = []
        filter = ""
    }

    func show(_ container: String, tab: DetailTab = .info) {
        section = .containers
        selectedContainerID = container
        selectedContainerIDs = [container]
        detailTab = tab
    }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
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
    var appearance: AppearanceChoice { didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") } }
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
        appearance = defaults.string(forKey: "appearance").flatMap { AppearanceChoice(rawValue: $0.capitalized) } ?? .system
        logCapacity = defaults.integer(forKey: "logCapacity")
        defaultDetailTab = defaults.string(forKey: "defaultDetailTab").flatMap(DetailTab.init(rawValue:)) ?? .info
    }
}
