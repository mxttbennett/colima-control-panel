import ServiceManagement

@MainActor
enum ColimaWatcherService {
    static let service = SMAppService.agent(plistName: "dev.mxttbennett.colima-ctrl.watcher.plist")

    static func register() throws {
        if service.status != .enabled && service.status != .requiresApproval { try service.register() }
    }

    static func unregister() throws {
        if service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
    }
}
