import Foundation

struct HistorySession: Codable, Identifiable {
    let id: UUID
    let date: Date
    let name: String
    let duration: TimeInterval // in seconds
    let isPomodoro: Bool
}

class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    
    @Published var history: [HistorySession] = []
    
    private let fileURL: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("FrogDrop", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()
    
    private init() {
        load()
    }
    
    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([HistorySession].self, from: data) {
            self.history = decoded.sorted(by: { $0.date > $1.date })
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: fileURL)
        }
    }
    
    func logSession(name: String, duration: TimeInterval, isPomodoro: Bool) {
        let newSession = HistorySession(
            id: UUID(),
            date: Date(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (isPomodoro ? "Focus Session" : "Timer") : name,
            duration: duration,
            isPomodoro: isPomodoro
        )
        DispatchQueue.main.async {
            self.history.insert(newSession, at: 0)
            self.save()
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            self.save()
        }
    }
}
