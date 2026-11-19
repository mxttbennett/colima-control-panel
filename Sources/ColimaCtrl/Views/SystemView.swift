import SwiftUI
import ColimaCtrlCore

struct SystemView: View {
    @Environment(FleetStore.self) private var store
    @State private var prune: PruneKind?

    var body: some View {
        ScrollView {
            if let disk = store.disk {
                let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]
                DiskBar(disk: disk).padding([.horizontal, .top], 20)
                LazyVGrid(columns: columns, spacing: 14) {
                    Summary(title: "Images", value: disk.images.size, detail: detail(disk.images), action: ("Prune unused", .imagesUnused), prune: $prune)
                    Summary(title: "Containers", value: disk.containers.size, detail: detail(disk.containers), action: ("Prune stopped", .containers), prune: $prune)
                    Summary(title: "Volumes", value: disk.volumes.size, detail: detail(disk.volumes), action: ("Prune unused", .volumes), prune: $prune)
                    Summary(title: "Build cache", value: disk.buildCache.size, detail: "\(disk.buildCache.count) entries · \(Format.bytes(disk.buildCache.reclaimable)) reclaimable", action: ("Prune", .buildCache), prune: $prune)
                    SelfCard()
                }
                .padding(20)
            } else {
                ProgressView().padding(40)
            }
        }
        .pruneConfirmation($prune)
    }

    private func detail(_ bucket: DiskBucket) -> String { "\(bucket.count) total · \(Format.bytes(bucket.reclaimable)) reclaimable" }
}

private struct DiskBar: View {
    let disk: DiskUsage

    private var segments: [(name: String, size: Int64, color: Color)] {
        [("Images", disk.images.size, Brand.blue), ("Containers", disk.containers.size, Brand.blue.opacity(0.7)),
         ("Volumes", disk.volumes.size, Brand.blue.opacity(0.45)), ("Build cache", disk.buildCache.size, Brand.blue.opacity(0.25))]
    }

    var body: some View {
        let total = max(disk.total, 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Docker disk").zoomFont(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Format.bytes(disk.total)).zoomFont(.title2.weight(.semibold)).rollingNumbers(disk.total)
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(segments, id: \.name) { segment in
                        segment.color.frame(width: max(2, proxy.size.width * CGFloat(segment.size) / CGFloat(total)))
                    }
                }
                .clipShape(.rect(cornerRadius: 5))
                .motion(Motion.smooth, value: disk)
            }
            .frame(height: 12)
            HStack(spacing: 16) {
                ForEach(segments, id: \.name) { segment in
                    HStack(spacing: 6) {
                        Circle().fill(segment.color).frame(width: 8, height: 8)
                        Text("\(segment.name) \(Format.bytes(segment.size))").zoomFont(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if disk.reclaimable >= 1_000_000_000, Double(disk.reclaimable) / Double(total) >= 0.25 {
                Label("\(Format.bytes(disk.reclaimable)) can be reclaimed with the prune buttons below", systemImage: "arrow.3.trianglepath")
                    .zoomFont(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

private struct SelfCard: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        let metrics = store.selfMetrics
        VStack(alignment: .leading, spacing: 4) {
            Text("This app").zoomFont(.caption).foregroundStyle(.secondary)
            Text(Format.bytes(Int64(metrics.memory))).zoomFont(.title2.weight(.semibold))
            Text("\(metrics.cpu, format: .number.precision(.fractionLength(1)))% CPU").zoomFont(.caption).foregroundStyle(.secondary)
            Sparkline(values: metrics.series.cpu, maximum: max(10, metrics.series.cpu.max() ?? 10), color: .secondary).frame(height: 30).padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentCard(cornerRadius: 18)
    }
}

private struct Summary: View {
    @Environment(FleetStore.self) private var store
    let title: String
    let value: Int64
    let detail: String
    var action: (String, PruneKind)?
    var prune: Binding<PruneKind?>?

    init(title: String, value: Int64, detail: String, action: (String, PruneKind)? = nil, prune: Binding<PruneKind?>? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
        self.action = action
        self.prune = prune
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).zoomFont(.caption).foregroundStyle(.secondary)
            Text(Format.bytes(value)).zoomFont(.title2.weight(.semibold))
            Text(detail).zoomFont(.caption).foregroundStyle(.secondary)
            if let action, let prune {
                HStack(spacing: 8) {
                    Button(action.0) { prune.wrappedValue = action.1 }.buttonStyle(.liquid(tint: .red)).controlSize(.small)
                        .disabled(store.pending[action.1.pendingKey] != nil)
                    if store.pending[action.1.pendingKey] != nil { ProgressView().controlSize(.small) }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .contentCard(cornerRadius: 18)
    }
}
