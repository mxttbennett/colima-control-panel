import SwiftUI
import ColimaCtrlCore

struct DownView: View {
    @Environment(FleetStore.self) private var store

    var body: some View {
        let vm = store.vm
        VStack(spacing: 14) {
            Image(systemName: vm.isBusy ? "hourglass" : "powerplug").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(title(vm)).font(.title2.weight(.semibold))
            Text(vm.isBusy ? "This can take a minute." : "Start it to see containers, images, and volumes.").foregroundStyle(.secondary)
            if !vm.isBusy { Button("Start Colima") { vm.run(.start) }.buttonStyle(.glassProminent).controlSize(.large) }
            if let error = vm.error { Text(error).foregroundStyle(.red) }
            if vm.isBusy || vm.error != nil, !vm.log.isEmpty { LogTail(lines: vm.log) }
        }
        .padding(30)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func title(_ vm: ColimaVM) -> String {
        switch vm.operation {
        case .start: "Starting Colima"
        case .restart: "Restarting Colima"
        case .stop: "Stopping Colima"
        case nil: "Colima is stopped"
        }
    }
}

private struct LogTail: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).id(index).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 260)
            .contentCard()
            .onChange(of: lines.count) { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
        }
    }
}
