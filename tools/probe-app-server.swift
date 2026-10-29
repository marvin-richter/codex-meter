#!/usr/bin/env swift
import Foundation

// Standalone feasibility probe. Never reads auth.json or prints credentials.
// Run: swift tools/probe-app-server.swift
let server = Process()
server.executableURL = URL(fileURLWithPath: "/usr/bin/env")
server.arguments = ["codex", "app-server", "--stdio", "-c", "analytics.enabled=false"]
let input = Pipe()
let output = Pipe()
server.standardInput = input
server.standardOutput = output
server.standardError = FileHandle.nullDevice
try server.run()
defer {
    try? input.fileHandleForWriting.close()
    if server.isRunning { server.terminate() }
}
func send(_ message: [String: Any]) throws {
    var data = try JSONSerialization.data(withJSONObject: message)
    data.append(10)
    try input.fileHandleForWriting.write(contentsOf: data)
}
func response(id: Int) throws -> [String: Any] {
    while true {
        var line = Data()
        while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte.first == 10 { break }
            line.append(byte)
        }
        guard !line.isEmpty else { throw CocoaError(.fileReadUnknown) }
        guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
        guard message["id"] as? Int == id else { continue }
        // Do not emit server error messages: they can contain account details.
        guard message["error"] == nil,
              let result = message["result"] as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return result
    }
}
try send(["id": 0, "method": "initialize", "params": ["clientInfo": [
    "name": "codex_meter_probe", "title": "Codex Meter Probe", "version": "0.1.0"
]]])
_ = try response(id: 0)
try send(["method": "initialized", "params": [:]])
try send(["id": 1, "method": "account/rateLimits/read"])
let result = try response(id: 1)
// Print an allowlisted projection of quota data, not the full response.
let limits = (result["rateLimitsByLimitId"] as? [String: Any])?["codex"] as? [String: Any]
    ?? result["rateLimits"] as? [String: Any] ?? [:]
var summary: [String: Any] = [:]
for slot in ["primary", "secondary"] {
    if let window = limits[slot] as? [String: Any] {
        summary[slot] = window.filter { ["usedPercent", "windowDurationMins", "resetsAt"].contains($0.key) }
    }
}
if let resets = result["rateLimitResetCredits"] as? [String: Any] {
    summary["bankedResetCount"] = resets["availableCount"]
}
let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
