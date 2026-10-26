import Foundation
import Testing
@testable import ColimaCtrlCore

private func frame(_ stream: UInt8, _ text: String) -> Data {
    let body = Data(text.utf8)
    var data = Data([stream, 0, 0, 0, UInt8(body.count >> 24 & 255), UInt8(body.count >> 16 & 255), UInt8(body.count >> 8 & 255), UInt8(body.count & 255)])
    data.append(body)
    return data
}

@Test func headParserReadsStatusHeadersAndLeftoverBody() {
    var parser = HeadParser()
    let raw = Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nTransfer-Encoding: chunked\r\n\r\n2\r\n".utf8)
    let result = parser.feed(raw)
    #expect(result?.head.status == 200)
    #expect(result?.head.contentLength == 2)
    #expect(result?.head.isChunked == true)
    #expect(result.map { String(decoding: $0.remainder, as: UTF8.self) } == "2\r\n")
}

@Test func headParserWaitsForTheFullHead() {
    var parser = HeadParser()
    #expect(parser.feed(Data("HTTP/1.1 200 OK\r\nA: b".utf8)) == nil)
}

@Test func chunkDecoderHandlesSplitChunksAndTerminator() {
    var decoder = ChunkDecoder()
    var out = Data()
    for piece in ["5\r\nhel", "lo\r\n6\r\n wor", "ld\r\n0\r\n\r\n"] {
        for chunk in decoder.feed(Data(piece.utf8)) { out.append(chunk) }
    }
    #expect(String(decoding: out, as: UTF8.self) == "hello world")
    #expect(decoder.isFinished)
}

@Test func demuxerReassemblesFramesSplitAcrossReads() {
    var demuxer = LogDemuxer()
    let whole = frame(2, "boom\n") + frame(1, "ok\n")
    #expect(demuxer.feed(whole.prefix(5)).isEmpty)
    let frames = demuxer.feed(whole.dropFirst(5))
    #expect(frames.map(\.stream) == [.err, .out])
    #expect(String(decoding: frames[0].data, as: UTF8.self) == "boom\n")
}

@Test func lineSplitterKeepsPartialLines() {
    var splitter = LineSplitter()
    #expect(splitter.feed(Data("a\r\nb".utf8)) == ["a"])
    #expect(splitter.feed(Data("c\n".utf8)) == ["bc"])
}

@Test func cpuPercentUsesTheDeltaBetweenSamples() {
    let old = StatsSample(containerTotal: 100, systemTotal: 600, cpus: 4, memory: 0, memoryLimit: 0)
    let new = StatsSample(containerTotal: 200, systemTotal: 1000, cpus: 4, memory: 0, memoryLimit: 0)
    #expect(new.cpuPercent(since: old) == 100)
    #expect(new.cpuPercent(since: new) == 0)
}

@Test func dockerDateParsesNanosecondTimestamps() {
    #expect(DockerDate.parse("2026-10-25T21:32:20.349132781Z") != nil)
    #expect(DockerDate.parse("2026-10-25T21:32:20Z") != nil)
}
