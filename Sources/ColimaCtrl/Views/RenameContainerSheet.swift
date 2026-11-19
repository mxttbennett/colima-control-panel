import SwiftUI
import ColimaCtrlCore

struct RenameContainerSheet: View {
    @Environment(FleetStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let row: ContainerRow
    @State private var name: String
    @FocusState private var focused: Bool

    init(row: ContainerRow) {
        self.row = row
        _name = State(initialValue: row.name)
    }

    private var problem: String? {
        ContainerName.problem(with: name, current: row.name, others: store.containers.filter { $0.id != row.id }.map(\.name))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename container").zoomFont(.title3.weight(.semibold))
            TextField("Container name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(rename)
            Text(name == row.name ? " " : problem ?? " ").zoomFont(.caption).foregroundStyle(.red)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.liquid)
                Button("Rename", action: rename).keyboardShortcut(.defaultAction).buttonStyle(.glassProminent).disabled(problem != nil)
            }
        }
        .padding(20).frame(width: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .presentationBackground(.clear)
        .onAppear { focused = true }
    }

    private func rename() {
        guard problem == nil else { return }
        store.rename(container: row.id, to: name)
        dismiss()
    }
}
