import AppKit
import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

@MainActor
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var items: [ClipboardItem] = []
    
    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var timer: Timer?
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FrogDrop")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("clipboard_history.json")
    }
    
    private init() {
        loadHistory()
        lastChangeCount = pasteboard.changeCount
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }
    
    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let newText = pasteboard.string(forType: .string), !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Avoid duplicates at the top
            if items.first?.text != newText {
                addEntry(newText)
            }
        }
    }
    
    private func addEntry(_ text: String) {
        let newItem = ClipboardItem(text: text, timestamp: Date())
        items.insert(newItem, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        saveHistory()
    }
    
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(item.text, forType: .string)
        // Update local changeCount so we don't treat it as a new external copy
        lastChangeCount = pasteboard.changeCount
        
        // Move item to the top of list
        if let index = items.firstIndex(of: item) {
            items.remove(at: index)
        }
        items.insert(item, at: 0)
        saveHistory()
        HapticManager.shared.click()
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearAll() {
        items.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
}
