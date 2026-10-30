public struct ColimaLaunchObserver {
    private var wasRunning = false

    public init() {}

    public mutating func shouldLaunchCCP(isRunning: Bool) -> Bool {
        defer { wasRunning = isRunning }
        return isRunning && !wasRunning
    }
}
