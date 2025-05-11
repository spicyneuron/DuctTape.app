import Foundation

// Config
let maxOutputLines = 20

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
}