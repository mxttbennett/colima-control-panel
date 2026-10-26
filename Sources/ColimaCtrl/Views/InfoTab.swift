import SwiftUI
import ColimaCtrlCore

struct InfoTab: View {
    @Environment(FleetStore.self) private var store
    let row: ContainerRow
    @State private var inspect: ContainerInspect?
    @State private var revealed: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Graphs(id: row.id, running: row.state == "running")
                if let inspect {
                    Card("Overview") {
                        Field("Image", inspect.image, copy: true)
                        Field("ID", String(inspect.id.prefix(12)), copy: inspect.id)
                        Field("Command", inspect.command, copy: true)
                        if let created = inspect.created { Field("Created", Format.ago(created)) }
                        Field("Restart", inspect.restartPolicy)
                        if let health = inspect.health { Field("Health", health) }
                    }
                    if !inspect.ports.isEmpty {
                        Card("Ports") {
                            ForEach(inspect.ports) { port in
                                HStack {
                                    Text(port.container).foregroundStyle(.secondary)
                                    Spacer()
                                    Link(destination: URL(string: "http://localhost:\(port.host)")!) { Text(verbatim: "localhost:\(port.host)") }.font(.system(size: 12, design: .monospaced))
                                    CopyButton(text: "localhost:\(port.host)")
                                }
                            }
                        }
                    }
                    if !inspect.mounts.isEmpty {
                        Card("Mounts") {
                            ForEach(inspect.mounts) { mount in
                                Field(mount.type, "\(mount.source) → \(mount.destination)\(mount.readOnly ? " (read-only)" : "")", copy: true)
                            }
                        }
                    }
                    if !inspect.attachments.isEmpty {
                        Card("Networks") {
                            ForEach(inspect.attachments) { Field($0.network, $0.address.isEmpty ? "–" : $0.address, copy: !$0.address.isEmpty) }
                        }
                    }
                    if !inspect.env.isEmpty {
                        Card("Environment") {
                            ForEach(Array(inspect.env.enumerated()), id: \.offset) { _, pair in
                                EnvRow(key: pair.key, value: pair.value, revealed: $revealed)
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .task(id: "\(row.id):\(row.state):\(row.health ?? "")") {
            if inspect == nil { inspect = store.cachedInspect(row.id) }
            if let fresh = try? await store.inspect(row.id), fresh != inspect { inspect = fresh }
        }
    }
}

private struct Graphs: View {
    @Environment(FleetStore.self) private var store
    let id: String
    let running: Bool

    var body: some View {
        let series = store.stats.series(for: id)
        HStack(spacing: 12) {
            GraphCard(title: "CPU", value: running ? "\(series.latestCPU.formatted(.number.precision(.fractionLength(1))))%" : "–", values: series.cpu, maximum: max(10, series.cpu.max() ?? 10))
            GraphCard(title: "Memory", value: running ? Format.bytes(Int64(series.latestMemory)) : "–", values: series.memory, maximum: max(1, (series.memory.max() ?? 1) * 1.25))
        }
    }
}

private struct GraphCard: View {
    let title: String
    let value: String
    let values: [Double]
    let maximum: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.caption.weight(.medium)).monospacedDigit()
            }
            Sparkline(values: values, maximum: maximum).frame(height: 44)
        }
        .padding(12)
        .contentCard()
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) { content }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(cornerRadius: 16)
    }
}

struct Field: View {
    let label: String
    let value: String
    let copy: String?

    init(_ label: String, _ value: String, copy: Bool = false) {
        self.label = label
        self.value = value
        self.copy = copy ? value : nil
    }

    init(_ label: String, _ value: String, copy: String) {
        self.label = label
        self.value = value
        self.copy = copy
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
            if let copy { CopyButton(text: copy) }
        }
    }
}

struct EnvRow: View {
    let key: String
    let value: String
    @Binding var revealed: Set<String>

    private var hidden: Bool { Self.secret.firstMatch(in: key) != nil && !revealed.contains(key) }
    private static let secret = try! NSRegularExpression(pattern: "pass|secret|token|key|pwd|credential|auth", options: .caseInsensitive)

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(.system(size: 12, design: .monospaced)).frame(maxWidth: 150, alignment: .leading).lineLimit(2)
            if hidden {
                Button("••••••••") { revealed.insert(key) }.buttonStyle(.plain).foregroundStyle(.tertiary).help("Reveal")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
            }
            CopyButton(text: value)
        }
    }
}

private extension NSRegularExpression {
    func firstMatch(in text: String) -> NSTextCheckingResult? {
        firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
