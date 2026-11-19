import SwiftUI
import UniformTypeIdentifiers
import ColimaCtrlCore

struct LogsTab: View {
    @Environment(FleetStore.self) private var store
    @Environment(Preferences.self) private var prefs
    let containerID: String
    @State private var model: LogModel?
    @State private var filter = ""
    @State private var appliedFilter = ""
    @State private var follow = true
    @AppStorage("logWrap") private var wrap = true
    @AppStorage("logTimestamps") private var timestamps = true
    @AppStorage("logFilterOnly") private var filterOnly = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Filter logs", text: $filter).textFieldStyle(.roundedBorder)
                Toggle("Follow", isOn: $follow).toggleStyle(.checkbox)
                Button("Copy", systemImage: "doc.on.doc") { copyVisible() }.labelStyle(.iconOnly).help("Copy the shown lines")
                Button("Clear", systemImage: "trash") { model?.clear() }.labelStyle(.iconOnly).help("Clear the log view")
                Menu("Log options", systemImage: "ellipsis.circle") {
                    Toggle("Wrap lines", isOn: $wrap)
                    Toggle("Show timestamps", isOn: $timestamps)
                    Toggle("Hide lines that don't match the filter", isOn: $filterOnly)
                    Divider()
                    Button("Save to File…") { save() }
                }
                .labelStyle(.iconOnly).menuStyle(.borderlessButton).fixedSize()
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if let model {
                LogList(model: model, filter: appliedFilter, follow: $follow, wrap: wrap, timestamps: timestamps, filterOnly: filterOnly)
            } else {
                Spacer()
            }
        }
        .onAppear {
            let created = LogModel(client: store.client, containerID: containerID, capacity: prefs.logCapacity)
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

    private var visibleLines: [LogLine] {
        guard let model else { return [] }
        return model.lines.filter { appliedFilter.isEmpty || $0.text.localizedCaseInsensitiveContains(appliedFilter) }
    }

    private func copyVisible() {
        Clipboard.copy(visibleLines.map(\.text).joined(separator: "\n"))
    }

    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(store.containers.first { $0.id == containerID }?.name ?? "container").log"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = visibleLines.map { "\($0.timestamp) \($0.text)" }.joined(separator: "\n") + "\n"
        do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { store.lastError = "Save logs: \(error.localizedDescription)" }
    }
}

private struct LogList: View {
    let model: LogModel
    let filter: String
    @Binding var follow: Bool
    let wrap: Bool
    let timestamps: Bool
    let filterOnly: Bool
    @State private var position = 0
    @State private var atBottom = true
    @State private var userScrolling = false

    var body: some View {
        let matching = filter.isEmpty ? [] : model.lines.filter { $0.text.localizedCaseInsensitiveContains(filter) }
        let visible = filter.isEmpty || !filterOnly ? model.lines : matching
        let matchIDs = matching.map(\.id)
        let current = matchIDs.indices.contains(position) ? matchIDs[position] : nil
        ScrollViewReader { proxy in
            ScrollView(wrap ? [.vertical] : [.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visible) { line in
                        row(line, current: line.id == current)
                            .font(.system(size: 11.5, design: .monospaced))
                            .fixedSize(horizontal: !wrap, vertical: true)
                            .frame(maxWidth: wrap ? .infinity : nil, alignment: .leading)
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
                if follow, let last = visible.last?.id { proxy.scrollTo(last, anchor: .bottomLeading) }
            }
            .overlay(alignment: .bottom) {
                if !follow {
                    Button("Jump to latest", systemImage: "arrow.down") {
                        follow = true
                        if let last = visible.last?.id { proxy.scrollTo(last, anchor: .bottomLeading) }
                    }
                    .buttonStyle(.glass).controlSize(.small).padding(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if !filter.isEmpty {
                    MatchBar(count: matchIDs.count, position: position) { step in
                        guard !matchIDs.isEmpty else { return }
                        position = (position + step + matchIDs.count) % matchIDs.count
                        follow = false
                        proxy.scrollTo(matchIDs[position], anchor: .center)
                    }
                    .padding(8)
                }
            }
            .onChange(of: filter) { position = 0 }
            .animation(.snappy, value: follow)
        }
        .overlay { if let failure = model.failure { Text(failure).foregroundStyle(.red).padding() } }
    }

    private func row(_ line: LogLine, current: Bool) -> Text {
        let body = Text(Self.styled(line, filter: filter, current: current)).foregroundStyle(line.isError ? Color.red : Color.primary)
        guard timestamps else { return body }
        return Text("\(Text(Self.time(line.timestamp)).foregroundStyle(.tertiary)) \(body)")
    }

    private static func styled(_ line: LogLine, filter: String, current: Bool) -> AttributedString {
        let text = line.text
        var result = AttributedString(text)

        func apply(_ range: Range<String.Index>, _ change: (inout AttributedSubstring) -> Void) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { return }
            change(&result[lower..<upper])
        }

        if let found = LogText.levelMatch(in: text) {
            apply(found.range) { slice in
                switch found.level {
                case .error: slice.foregroundColor = .red
                case .warning: slice.foregroundColor = .orange
                case .debug: slice.foregroundColor = .secondary
                case .info: slice.foregroundColor = .blue
                }
                slice.font = .system(size: 11.5, weight: .semibold, design: .monospaced)
            }
        }
        for link in LogText.links(in: text) { apply(link.range) { $0.link = link.url } }
        for range in LogText.matches(of: filter, in: text) { apply(range) { $0.backgroundColor = current ? .orange.opacity(0.6) : .yellow.opacity(0.35) } }
        return result
    }

    /// "2026-10-25T21:32:20.349132781Z" → "21:32:20.349"
    private static func time(_ stamp: String) -> String {
        guard stamp.count >= 23 else { return stamp }
        let start = stamp.index(stamp.startIndex, offsetBy: 11)
        return String(stamp[start..<stamp.index(start, offsetBy: 12)])
    }
}

private struct MatchBar: View {
    let count: Int
    let position: Int
    let step: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(count == 0 ? "No matches" : "\(min(position, count - 1) + 1) of \(count)").font(.caption).monospacedDigit()
            Button("Previous Match", systemImage: "chevron.up") { step(-1) }.keyboardShortcut("g", modifiers: [.command, .shift]).help("Previous match (⇧⌘G)").disabled(count == 0)
            Button("Next Match", systemImage: "chevron.down") { step(1) }.keyboardShortcut("g", modifiers: .command).help("Next match (⌘G)").disabled(count == 0)
        }
        .labelStyle(.iconOnly).buttonStyle(.borderless)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
