import Foundation

/// Run a shell command synchronously and return output + exit code.
@discardableResult
public func shell(_ command: String) -> (output: String, exitCode: Int32) {
    let process = Process()
    let pipe = Pipe()

    process.standardOutput = pipe
    process.standardError = pipe
    process.arguments = ["-c", command]
    process.launchPath = "/bin/zsh"
    process.standardInput = nil

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ("Error: \(error.localizedDescription)", -1)
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    return (output.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
}
