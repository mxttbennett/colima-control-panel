import SwiftUI
import ColimaCtrlCore

struct ImagesView: View {
    @Environment(FleetStore.self) private var store
    @Environment(UIState.self) private var ui
    @State private var sortOrder = [KeyPathComparator(\ImageRow.size, order: .reverse)]
    @State private var prune: PruneKind?
    @State private var removals: [ImageRow] = []

    var body: some View {
        let rows = store.images.filter { ui.filter.isEmpty || $0.title.localizedCaseInsensitiveContains(ui.filter) }.sorted(using: sortOrder)
        @Bindable var ui = ui
        Table(rows, selection: $ui.selectedImageIDs, sortOrder: $sortOrder) {
            TableColumn("Image", value: \.title) { Text($0.title).lineLimit(1).truncationMode(.middle) }
            TableColumn("Status") { Tag($0.containers > 0 ? "in use · \($0.containers)" : "unused") }.width(100)
            TableColumn("Size", value: \.size) { Text(Format.bytes($0.size)).monospacedDigit() }.width(90)
            TableColumn("Created", value: \.created) { Text(Format.ago($0.created)).foregroundStyle(.secondary) }.width(110)
            TableColumn("") { image in Button("Remove", systemImage: "trash") { removals = [image] }.labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.red) }.width(36)
        }
        .scrollContentBackground(.hidden)
        .deselectsOnReclick()
        .contextMenu(forSelectionType: String.self) { ids in
            let picked = rows.filter { ids.contains($0.id) }
            if let image = picked.first, picked.count == 1 {
                Button("Copy Name") { Clipboard.copy(image.tags.first ?? image.id) }
                Button("Copy ID") { Clipboard.copy(image.id) }
                if let user = store.containers.first(where: { $0.imageID == image.id }) {
                    Button("Show Container \(user.title)") { ui.show(user.id) }
                }
                Divider()
                Button("Remove…", role: .destructive) { removals = [image] }
            } else if picked.count > 1 {
                Button("Copy \(picked.count) Names") { Clipboard.copy(picked.map { $0.tags.first ?? $0.id }.joined(separator: "\n")) }
                let unused = picked.filter { $0.containers == 0 }
                if !unused.isEmpty {
                    Divider()
                    Button(unused.count == picked.count ? "Remove \(picked.count) Images…" : "Remove \(unused.count) Unused Images…", role: .destructive) { removals = unused }
                }
            }
        }
        .sheet(isPresented: $ui.showPull) { PullImageSheet() }
        .toolbar {
            ToolbarItem { Button("Pull Image", systemImage: "arrow.down.circle") { ui.showPull = true }.help("Pull an image from a registry") }
            ToolbarItem {
                Menu("Prune", systemImage: "trash") {
                    Button("Dangling images") { prune = .imagesDangling }
                    Button("All unused images") { prune = .imagesUnused }
                }.tint(.red)
            }
        }
        .pruneConfirmation($prune)
        .confirmationDialog(removals.count == 1 ? "Remove image \(removals[0].title)?" : "Remove \(removals.count) images?", isPresented: Binding(get: { !removals.isEmpty }, set: { if !$0 { removals = [] } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) { store.remove(images: removals.map(\.id)) }
        }
        .overlay {
            if !store.hasLoaded { ProgressView("Loading images…") } else if rows.isEmpty { ContentUnavailableView("No images", systemImage: "square.stack.3d.up") }
        }
    }
}

private struct PullImageSheet: View {
    @Environment(FleetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""
    @State private var progress: PullProgress?
    @State private var failure: String?
    @State private var task: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pull image").font(.title3.weight(.semibold))
            TextField("nginx:alpine or registry.example.com/team/app:1.2", text: $reference)
                .textFieldStyle(.roundedBorder).focused($focused).disabled(task != nil).onSubmit(start)
            if task != nil, let progress {
                ProgressView(value: progress.fraction) { Text(progress.status).font(.caption).foregroundStyle(.secondary) }
            }
            if let failure { Text(failure).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("Cancel") { task?.cancel(); dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.liquid)
                Button("Pull", action: start).keyboardShortcut(.defaultAction).buttonStyle(.glassProminent).disabled(!ImageReference(reference).isValid || task != nil)
            }
        }
        .padding(20).frame(width: 460)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .presentationBackground(.clear)
        .onAppear { focused = true }
        .onDisappear { task?.cancel() }
    }

    private func start() {
        let image = ImageReference(reference)
        guard image.isValid, task == nil else { return }
        failure = nil
        task = Task {
            do {
                try await store.pull(image: image) { progress = $0 }
                dismiss()
            } catch {
                if !Task.isCancelled { failure = error.localizedDescription }
                task = nil
            }
        }
    }
}
