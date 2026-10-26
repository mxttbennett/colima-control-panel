import SwiftUI
import ColimaCtrlCore

struct PaneTarget: Equatable {
    let section: Section
    let id: String
}

/// Hosts the main content and slides the selected row's detail in from the right.
/// The panel overlays the content instead of resizing it, so opening or closing never re-lays-out the list underneath,
/// and it stays mounted briefly after closing so reopening the same row costs a slide, not a rebuild.
struct PaneHost<Content: View>: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: Content
    @State private var mounted: PaneTarget?

    private let width: CGFloat = 400
    private let keepMounted: Duration = .seconds(3)

    var body: some View {
        let target = ui.paneSelection.map { PaneTarget(section: ui.section, id: $0) }.flatMap { exists($0) ? $0 : nil }
        let open = target != nil
        ZStack(alignment: .trailing) {
            content
            if let mounted, exists(mounted) {
                pane(mounted)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(alignment: .leading) { Divider() }
                    .offset(x: open && mounted == target ? 0 : width + 1)
                    .allowsHitTesting(open && mounted == target)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: open)
            }
        }
        .onChange(of: target, initial: true) { _, new in
            if let new { mounted = new }
        }
        .task(id: open) {
            guard !open else { return }
            try? await Task.sleep(for: keepMounted)
            if !Task.isCancelled { mounted = nil }
        }
        .onExitCommand { ui.closePane() }
    }

    private func exists(_ target: PaneTarget) -> Bool {
        switch target.section {
        case .containers: store.containers.contains { $0.id == target.id }
        case .volumes: store.volumes.contains { $0.name == target.id }
        case .images: store.images.contains { $0.id == target.id }
        case .networks: store.networks.contains { $0.id == target.id }
        case .system: false
        }
    }

    @ViewBuilder private func pane(_ target: PaneTarget) -> some View {
        switch target.section {
        case .containers: ContainerDetailView(id: target.id)
        case .volumes: VolumeDetailView(name: target.id)
        case .images: ImageDetailView(id: target.id)
        case .networks: NetworkDetailView(id: target.id)
        case .system: EmptyView()
        }
    }
}
