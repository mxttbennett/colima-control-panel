import SwiftUI
import ColimaCtrlCore

struct LogsTab: View {
    @Environment(FleetStore.self) private var store
    let containerID: String
    @State private var model: LogModel?
    @State private var filter = ""
    @State private var appliedFilter = ""
    @State private var follow = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Filter logs", text: $filter).textFieldStyle(.roundedBorder)
                Toggle("Follow", isOn: $follow).toggleStyle(.checkbox)
                Button("Copy", systemImage: "doc.on.doc") { copyVisible() }.labelStyle(.iconOnly).help("Copy the shown lines")
                Button("Clear", systemImage: "trash") { model?.clear() }.labelStyle(.iconOnly).help("Clear the log view")
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if let model {
                LogList(model: model, filter: appliedFilter, follow: $follow)
            } else {
                Spacer()
            }
        }
        .onAppear {
            let created = LogModel(client: store.client, containerID: containerID)
            created.start()
            model = created
        }
        .onDisappear { model?.stop() }
        .task(id: filter) {
            if filter.isEmpty { appliedFilter = ""; return }
            try? await Task.sleep(for: .milliseconds(150))
            appliedFilter = filter
        }
    }

    private func copyVisible() {
        guard let model else { return }
        let text = model.lines.filter { appliedFilter.isEmpty || $0.text.localizedCaseInsensitiveContains(appliedFilter) }.map(\.text).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct LogList: View {
    let model: LogModel
    let filter: String
    @Binding var follow: Bool
    @State private var atBottom = true
    @State private var userScrolling = false

    var body: some View {
        let visible = filter.isEmpty ? model.lines : model.lines.filter { $0.text.localizedCaseInsensitiveContains(filter) }
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visible) { line in
                        Text("\(Text(Self.time(line.timestamp)).foregroundStyle(.tertiary)) \(Text(line.text).foregroundStyle(line.isError ? Color.red : Color.primary))")
                            .font(.system(size: 11.5, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .textSelection(.enabled)
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.containerSize.height >= $0.contentSize.height - 24 } action: { _, new in atBottom = new }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { userScrolling = true }
                if phase == .idle, userScrolling {
                    userScrolling = false
                    follow = atBottom
                }
            }
            .onChange(of: model.lines.last?.id) {
                if follow, let last = visible.last?.id { proxy.scrollTo(last, anchor: .bottom) }
            }
            .overlay(alignment: .bottom) {
                if !follow {
                    Button("Jump to latest", systemImage: "arrow.down") {
                        follow = true
                        if let last = visible.last?.id { proxy.scrollTo(last, anchor: .bottom) }
                    }
                    .buttonStyle(.glass).controlSize(.small).padding(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: follow)
        }
        .overlay { if let failure = model.failure { Text(failure).foregroundStyle(.red).padding() } }
    }

    /// "2026-10-25T21:32:20.349132781Z" → "21:32:20.349"
    private static func time(_ stamp: String) -> String {
        guard stamp.count >= 23 else { return stamp }
        let start = stamp.index(stamp.startIndex, offsetBy: 11)
        return String(stamp[start..<stamp.index(start, offsetBy: 12)])
    }
}
