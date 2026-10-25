import SwiftUI
import ColimaCtrlCore

struct LogsTab: View {
    @Environment(FleetStore.self) private var store
    let containerID: String
    @State private var model: LogModel?
    @State private var filter = ""
    @State private var follow = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Filter logs", text: $filter).textFieldStyle(.roundedBorder)
                Toggle("Follow", isOn: $follow).toggleStyle(.checkbox)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if let model {
                LogList(model: model, filter: filter, follow: follow)
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
    }
}

private struct LogList: View {
    let model: LogModel
    let filter: String
    let follow: Bool

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
            .onChange(of: model.lines.last?.id) {
                if follow, let last = visible.last?.id { proxy.scrollTo(last, anchor: .bottom) }
            }
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
