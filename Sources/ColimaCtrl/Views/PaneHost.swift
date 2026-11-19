import SwiftUI
import ColimaCtrlCore

struct PaneTarget: Equatable {
    let section: Section
    let id: String
}

/// Hosts the main content and slides the selected row's detail in from the right.
/// The content makes room for the panel, so row buttons and graphs stay visible beside it,
/// and the panel stays mounted briefly after closing so reopening the same row costs a slide, not a rebuild.
private let paneDefaultWidth: Double = 400
private let paneInset: CGFloat = 8
private let paneCornerRadius: CGFloat = 22

struct PaneHost<Content: View>: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder let content: Content
    @State private var mounted: PaneTarget?

    @AppStorage("paneWidth") private var storedWidth: Double = paneDefaultWidth
    @State private var dragStartWidth: Double?

    private var width: CGFloat { CGFloat(storedWidth) }
    private let widthRange: ClosedRange<Double> = 320...1000
    private let keepMounted: Duration = .seconds(3)

    private var resizeHandle: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .onTapGesture(count: 2) { storedWidth = paneDefaultWidth }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let start = dragStartWidth ?? storedWidth
                        dragStartWidth = start
                        storedWidth = min(max(start - drag.translation.width, widthRange.lowerBound), widthRange.upperBound)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
            .offset(x: -4)
    }

    var body: some View {
        let target = ui.paneSelection.map { PaneTarget(section: ui.section, id: $0) }.flatMap { exists($0) ? $0 : nil }
        let open = target != nil
        ZStack(alignment: .trailing) {
            content
                .padding(.trailing, open ? width + paneInset * 2 : 0)
                .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: open)
            if let mounted, exists(mounted) {
                pane(mounted)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .top) { Rectangle().fill(mounted.section.color.opacity(0.85)).frame(height: 3) }
                    .clipShape(.rect(cornerRadius: paneCornerRadius))
                    .glassEffect(.regular, in: .rect(cornerRadius: paneCornerRadius))
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 4)
                    .overlay(alignment: .leading) { resizeHandle }
                    .padding(paneInset)
                    .offset(x: open && mounted == target ? 0 : width + paneInset * 2 + 1)
                    .allowsHitTesting(open && mounted == target)
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: open)
            }
        }
        .background { AmbientBackground() }
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
        case .containers: target.id == UIState.multiSelection || store.containers.contains { $0.id == target.id }
        case .volumes: store.volumes.contains { $0.name == target.id }
        case .images: store.images.contains { $0.id == target.id }
        case .networks: store.networks.contains { $0.id == target.id }
        case .system: false
        }
    }

    @ViewBuilder private func pane(_ target: PaneTarget) -> some View {
        switch target.section {
        case .containers:
            if target.id == UIState.multiSelection { MultiSelectionPane() } else { ContainerDetailView(id: target.id) }
        case .volumes: VolumeDetailView(name: target.id)
        case .images: ImageDetailView(id: target.id)
        case .networks: NetworkDetailView(id: target.id)
        case .system: EmptyView()
        }
    }
}
