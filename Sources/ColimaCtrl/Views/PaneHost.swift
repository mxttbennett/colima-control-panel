import SwiftUI
import ColimaCtrlCore

/// Hosts the main content and slides the container detail in from the right.
/// The panel overlays the content instead of resizing it, so opening or closing never re-lays-out the list underneath,
/// and it stays mounted briefly after closing so reopening the same container costs a slide, not a rebuild.
struct PaneHost<Content: View>: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: Content
    @State private var mounted: String?

    private let width: CGFloat = 400
    private let keepMounted: Duration = .seconds(3)

    var body: some View {
        let selected = ui.selectedContainerID.flatMap { id in store.containers.contains { $0.id == id } ? id : nil }
        let open = ui.section == .containers && selected != nil
        ZStack(alignment: .trailing) {
            content
            if let mounted, store.containers.contains(where: { $0.id == mounted }) {
                ContainerDetailView(id: mounted)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(alignment: .leading) { Divider() }
                    .offset(x: open ? 0 : width + 1)
                    .allowsHitTesting(open)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: open)
            }
        }
        .onChange(of: selected, initial: true) { _, new in
            if let new { mounted = new }
        }
        .task(id: open) {
            guard !open else { return }
            try? await Task.sleep(for: keepMounted)
            if !Task.isCancelled { mounted = nil }
        }
    }
}
