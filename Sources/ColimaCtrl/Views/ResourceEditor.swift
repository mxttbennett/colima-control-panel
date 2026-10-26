import SwiftUI
import ColimaCtrlCore

/// Sliders for the resources Colima's VM may use, bounded by what this Mac has.
struct ResourceEditor: View {
    @Binding var resources: ColimaResources
    let host: HostSpecs
    /// Colima can grow the disk but never shrink it.
    var minimumDisk: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            row("CPU cores", detail: "\(resources.cpus) of \(host.cores)") {
                Slider(value: binding(\.cpus), in: 1...Double(host.maxCPUs), step: 1)
            }
            row("Memory", detail: "\(resources.memory) GiB of \(host.memoryGiB) GiB") {
                Slider(value: binding(\.memory), in: 2...Double(host.maxMemory), step: 1)
            }
            row("Disk", detail: "\(resources.disk) GiB") {
                Slider(value: binding(\.disk), in: Double(minimumDisk ?? 20)...Double(max(500, minimumDisk ?? 0)), step: 10)
            }
            if minimumDisk != nil {
                Text("Colima can grow the disk but not shrink it.").font(.caption).foregroundStyle(.secondary)
            }
            if resources.memory * 2 > host.memoryGiB || resources.cpus * 3 > host.cores * 2 {
                Label("That is more than half of this Mac. Other apps may feel slower while containers are busy.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func row<Control: View>(_ title: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(detail).foregroundStyle(.secondary).monospacedDigit()
            }
            control()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ColimaResources, Int>) -> Binding<Double> {
        Binding(get: { Double(resources[keyPath: keyPath]) }, set: { resources[keyPath: keyPath] = Int($0.rounded()) })
    }
}
