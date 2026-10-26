import Testing
@testable import ColimaCtrlCore

private let sample = """
# Number of CPUs to be allocated to the virtual machine.
cpu: 3

# Size of the disk in GiB.
disk: 100

memory: 8
arch: aarch64
network:
  address: false
"""

@Test func configParsesTheThreeResourceKeys() {
    #expect(ColimaConfigFile.parse(sample) == ColimaResources(cpus: 3, memory: 8, disk: 100))
}

@Test func configParseRoundsFractionalMemoryAndRejectsMissingKeys() {
    #expect(ColimaConfigFile.parse("cpu: 2\nmemory: 3.5\ndisk: 60\n")?.memory == 4)
    #expect(ColimaConfigFile.parse("cpu: 2\nmemory: 4\n") == nil)
}

@Test func configUpdateChangesOnlyTheResourceLines() {
    let updated = ColimaConfigFile.update(sample, with: ColimaResources(cpus: 6, memory: 12, disk: 120))
    #expect(ColimaConfigFile.parse(updated) == ColimaResources(cpus: 6, memory: 12, disk: 120))
    #expect(updated.contains("# Number of CPUs to be allocated"))
    #expect(updated.contains("arch: aarch64") && updated.contains("  address: false"))
}

@Test func configUpdateAddsMissingKeys() {
    let updated = ColimaConfigFile.update("arch: aarch64\n", with: ColimaResources(cpus: 2, memory: 4, disk: 80))
    #expect(ColimaConfigFile.parse(updated) == ColimaResources(cpus: 2, memory: 4, disk: 80))
}

@Test func recommendationsScaleWithTheMacAndStayWithinBounds() {
    #expect(HostSpecs(cores: 10, memoryGiB: 24).recommended == ColimaResources(cpus: 5, memory: 6, disk: 100))
    #expect(HostSpecs(cores: 4, memoryGiB: 8).recommended == ColimaResources(cpus: 2, memory: 2, disk: 100))
    #expect(HostSpecs(cores: 24, memoryGiB: 128).recommended == ColimaResources(cpus: 8, memory: 16, disk: 100))
    #expect(HostSpecs(cores: 10, memoryGiB: 24).maxMemory == 20)
}

@Test func vmArgumentsAppendExtrasAfterTheProfile() {
    #expect(ColimaVM.arguments(for: .start, profile: "default", extra: ["--cpus", "4"]) == ["start", "--cpus", "4"])
    #expect(ColimaVM.arguments(for: .start, profile: "work", extra: ["--cpus", "4"]) == ["start", "--profile", "work", "--cpus", "4"])
}
