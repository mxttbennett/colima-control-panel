import Foundation
import Testing
@testable import ColimaCtrlCore

@Test func footprintIsReportedInBytes() {
    #expect(SelfMetrics.footprint() > 1_000_000)
}

@Test func cpuSecondsGrowWithWork() {
    let before = SelfMetrics.cpuSeconds()
    var total = 0.0
    for i in 0..<5_000_000 { total += sqrt(Double(i)) }
    #expect(total > 0)
    #expect(SelfMetrics.cpuSeconds() > before)
}

@MainActor @Test func samplingFillsTheSeries() {
    let metrics = SelfMetrics()
    metrics.sample()
    metrics.sample()
    #expect(metrics.series.cpu.count == 2)
    #expect(metrics.memory > 0)
}
