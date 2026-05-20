import Foundation

private let logURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("extension.log")
}()

/// Cached formatter — `ISO8601DateFormatter` is thread-safe with immutable config.
/// `nonisolated(unsafe)` because ISO8601DateFormatter doesn't conform to Sendable,
/// but it's effectively immutable after initialization (no properties are mutated).
private nonisolated(unsafe) let logDateFormatter = ISO8601DateFormatter()

/// Recursively dump an object's Mirror for debugging XPC types.
func dumpMirror(_ obj: Any, label: String = "root", depth: Int = 3, indent: Int = 0) {
    let prefix = String(repeating: "  ", count: indent)
    let mirror = Mirror(reflecting: obj)
    extensionLog("\(prefix)[\(label)] type=\(type(of: obj)) children=\(mirror.children.count)")
    guard depth > 0 else { return }
    for child in mirror.children {
        let childLabel = child.label ?? "?"
        let childValue = child.value
        let desc = String(describing: childValue).prefix(200)
        extensionLog("\(prefix)  .\(childLabel) = \(desc)")
        // Recurse into non-primitive types
        let childMirror = Mirror(reflecting: childValue)
        if childMirror.children.count > 0, !(childValue is String), !(childValue is Data), !(childValue is URL) {
            dumpMirror(childValue, label: childLabel, depth: depth - 1, indent: indent + 2)
        }
    }
}

func extensionLog(_ message: String) {
    let ts = logDateFormatter.string(from: Date())
    let line = "[\(ts)] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}
