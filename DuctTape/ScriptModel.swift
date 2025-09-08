import Foundation

enum ScriptStatus {
    case idle
    case running
    case error

    var icon: String {
        switch self {
        case .idle: return "⚪️"
        case .running: return "🟢"
        case .error: return "🔴"
        }
    }
}

struct ScriptItem: Identifiable {
    let id = UUID()
    let url: URL
    var status: ScriptStatus = .idle
    var process: Process? = nil
    var autoStart: Bool = false
    var outputLines: [String] = []
    var outputLinesChanged: Bool = false

    init(url: URL, autoStart: Bool = false) {
        self.url = url
        self.autoStart = autoStart

        do {
            _ = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            self.status = .error
            self.outputLines = [
                "Cannot access script: \(url.path)",
                "Error: \(error.localizedDescription)"
            ]
        }
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}