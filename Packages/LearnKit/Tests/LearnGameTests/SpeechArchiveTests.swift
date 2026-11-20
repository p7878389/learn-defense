import Foundation
import CryptoKit
import Testing
@testable import LearnGame

struct SpeechArchiveTests {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private func zip(_ name: String) throws -> (URL, String) {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = Data(base64Encoded: Self.fixtures[name]!)!
        let url = root.appendingPathComponent(name + ".zip")
        try data.write(to: url)
        return (url, SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }

    @Test func installsAllClipsAndReusesSnapshotOffline() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (zip, hash) = try zip("valid")
        let cache = root.appendingPathComponent("remote")
        let installed = try SpeechArchive.install(zip, sha256: hash, in: cache)
        #expect(installed.manifest.clips.count == 2)
        #expect(try Data(contentsOf: installed.directory.appendingPathComponent("game/你好.mp3")) == Data("hello-audio".utf8))
        #expect(SpeechArchive.current(in: cache)?.manifest.voice == "fixture-voice")
        #expect(SpeechArchive.current(in: cache, sha256: hash)?.directory == installed.directory)
        try FileManager.default.removeItem(at: installed.directory.appendingPathComponent("game/再见.mp3"))
        #expect(SpeechArchive.current(in: cache, sha256: hash) == nil, "缺文件必须重新准备整包")
    }

    @Test(arguments: ["missing", "traversal", "symlink"])
    func rejectsBadArchiveAndKeepsPreviousSnapshot(_ kind: String) throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("remote")
        let (good, hash) = try zip("valid")
        let installed = try SpeechArchive.install(good, sha256: hash, in: cache)
        let (bad, badHash) = try zip(kind)
        #expect(throws: (any Error).self) { try SpeechArchive.install(bad, sha256: badHash, in: cache) }
        #expect(SpeechArchive.current(in: cache)?.directory == installed.directory)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("escape.mp3").path))
    }

    @Test func rejectsWrongChecksumBeforeReplacingLegacyCache() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (file, _) = try zip("valid")
        let cache = root.appendingPathComponent("remote")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let old = cache.appendingPathComponent("old.mp3")
        try Data("old".utf8).write(to: old)
        #expect(throws: (any Error).self) { try SpeechArchive.install(file, sha256: String(repeating: "0", count: 64), in: cache) }
        #expect(try Data(contentsOf: old) == Data("old".utf8))
    }

    static let fixtures: [String: String] = [
        "valid": "UEsDBBQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAbWFuaWZlc3QuanNvbqtWKkstKs7Mz1OyUjDUUVAqy89MTgWyldIyK0pKi1J1IQJAmeSczIJioEy10pO9C54u3QtSlJ6Ym6oP4erlFhiDlD1t632xvBEuCeGCJWtrAVBLAwQUAAAICACXu3RdjSXekw0AAAALAAAADwAAAGdhbWUv5L2g5aW9Lm1wM8tIzcnJ100sTcnMBwBQSwMEFAAACAgAl7t0XRWDYJsLAAAACQAAAA8AAABnYW1lL+WGjeingS5tcDNLqkzVTSxNycwHAFBLAQIUAxQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAAAAAAAAAAACAAQAAAABtYW5pZmVzdC5qc29uUEsBAhQDFAAACAgAl7t0XY0l3pMNAAAACwAAAA8AAAAAAAAAAAAAAIABfAAAAGdhbWUv5L2g5aW9Lm1wM1BLAQIUAxQAAAgIAJe7dF0Vg2CbCwAAAAkAAAAPAAAAAAAAAAAAAACAAbYAAABnYW1lL+WGjeingS5tcDNQSwUGAAAAAAMAAwC1AAAA7gAAAAAA",
        "missing": "UEsDBBQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAbWFuaWZlc3QuanNvbqtWKkstKs7Mz1OyUjDUUVAqy89MTgWyldIyK0pKi1J1IQJAmeSczIJioEy10pO9C54u3QtSlJ6Ym6oP4erlFhiDlD1t632xvBEuCeGCJWtrAVBLAwQUAAAICACXu3RdjSXekw0AAAALAAAADwAAAGdhbWUv5L2g5aW9Lm1wM8tIzcnJ100sTcnMBwBQSwECFAMUAAAACACXu3RdUxge8VEAAABtAAAADQAAAAAAAAAAAAAAgAEAAAAAbWFuaWZlc3QuanNvblBLAQIUAxQAAAgIAJe7dF2NJd6TDQAAAAsAAAAPAAAAAAAAAAAAAACAAXwAAABnYW1lL+S9oOWlvS5tcDNQSwUGAAAAAAIAAgB4AAAAtgAAAAAA",
        "traversal": "UEsDBBQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAbWFuaWZlc3QuanNvbqtWKkstKs7Mz1OyUjDUUVAqy89MTgWyldIyK0pKi1J1IQJAmeSczIJioEy10pO9C54u3QtSlJ6Ym6oP4erlFhiDlD1t632xvBEuCeGCJWtrAVBLAwQUAAAICACXu3RdjSXekw0AAAALAAAADwAAAGdhbWUv5L2g5aW9Lm1wM8tIzcnJ100sTcnMBwBQSwMEFAAACAgAl7t0XRWDYJsLAAAACQAAAA8AAABnYW1lL+WGjeingS5tcDNLqkzVTSxNycwHAFBLAwQUAAAACACXu3Rd+zkrggUAAAADAAAADQAAAC4uL2VzY2FwZS5tcDNLSkwBAFBLAQIUAxQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAAAAAAAAAAACAAQAAAABtYW5pZmVzdC5qc29uUEsBAhQDFAAACAgAl7t0XY0l3pMNAAAACwAAAA8AAAAAAAAAAAAAAIABfAAAAGdhbWUv5L2g5aW9Lm1wM1BLAQIUAxQAAAgIAJe7dF0Vg2CbCwAAAAkAAAAPAAAAAAAAAAAAAACAAbYAAABnYW1lL+WGjeingS5tcDNQSwECFAMUAAAACACXu3Rd+zkrggUAAAADAAAADQAAAAAAAAAAAAAAgAHuAAAALi4vZXNjYXBlLm1wM1BLBQYAAAAABAAEAPAAAAAeAQAAAAA=",
        "symlink": "UEsDBBQAAAAIAJe7dF1TGB7xUQAAAG0AAAANAAAAbWFuaWZlc3QuanNvbqtWKkstKs7Mz1OyUjDUUVAqy89MTgWyldIyK0pKi1J1IQJAmeSczIJioEy10pO9C54u3QtSlJ6Ym6oP4erlFhiDlD1t632xvBEuCeGCJWtrAVBLAwQUAAAICACXu3RdjSXekw0AAAALAAAADwAAAGdhbWUv5L2g5aW9Lm1wM8tIzcnJ100sTcnMBwBQSwMEFAAACAgAl7t0XRWDYJsLAAAACQAAAA8AAABnYW1lL+WGjeingS5tcDNLqkzVTSxNycwHAFBLAwQUAAAAAAAAACEABlD98AoAAAAKAAAABAAAAGxpbmsuLi9vdXRzaWRlUEsBAhQDFAAAAAgAl7t0XVMYHvFRAAAAbQAAAA0AAAAAAAAAAAAAAIABAAAAAG1hbmlmZXN0Lmpzb25QSwECFAMUAAAICACXu3RdjSXekw0AAAALAAAADwAAAAAAAAAAAAAAgAF8AAAAZ2FtZS/kvaDlpb0ubXAzUEsBAhQDFAAACAgAl7t0XRWDYJsLAAAACQAAAA8AAAAAAAAAAAAAAIABtgAAAGdhbWUv5YaN6KeBLm1wM1BLAQIUAxQAAAAAAAAAIQAGUP3wCgAAAAoAAAAEAAAAAAAAAAAAAAD/oe4AAABsaW5rUEsFBgAAAAAEAAQA5wAAABoBAAAAAA=="
    ]
}
