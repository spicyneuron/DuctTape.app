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
    var outputLines: [String] = []
    var autoStart: Bool = false

    init(url: URL, autoStart: Bool = false) {
        self.url = url
        self.autoStart = autoStart
        if !FileManager.default.fileExists(atPath: url.path) {
            self.status = .error
            self.outputLines = ["Error: Script file not found at \(url.path)"]
        }
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}