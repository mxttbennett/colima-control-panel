public struct ColimaLaunchObserver {
    private var wasRunning: Bool?

    public init() {}

    public mutating func shouldLaunchCCP(isRunning: Bool) -> Bool {
        defer { wasRunning = isRunning }
        return isRunning && wasRunning == false
    }
}
