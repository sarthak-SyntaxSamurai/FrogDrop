import AppKit
import Foundation

// Struct representing a rule for clipboard behavior
struct ClipboardPreferenceRule: Identifiable, Codable, Equatable {
    var id = UUID()
    let appName: String
    enum RuleType: String, Codable {
        case save = "save"
        case ignore = "ignore"
        case temporary = "temporary"
    }
    var ruleType: RuleType
}

struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    let text: String
    let timestamp: Date
    let sourceApp: String?
    var isTemporary: Bool
    var expiresAt: Date?
    var isPinned: Bool = false

    init(id: UUID = UUID(), text: String, timestamp: Date = Date(), sourceApp: String? = nil, isTemporary: Bool = false, expiresAt: Date? = nil, isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.isTemporary = isTemporary
        self.expiresAt = expiresAt
        self.isPinned = isPinned
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, timestamp, sourceApp, isTemporary, expiresAt, isPinned
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        isTemporary = try container.decodeIfPresent(Bool.self, forKey: .isTemporary) ?? false
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

@MainActor
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var items: [ClipboardItem] = []
    @Published var customRules: [ClipboardPreferenceRule] = []
    @Published var tempDuration: TimeInterval = 60.0 // Default 60 seconds (1 minute)
    
    private let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    private let rulesKey = "frogdrop.clipboardRules"
    private let durationKey = "frogdrop.tempDuration"
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let appDir = appSupport.appendingPathComponent("FrogDrop")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("clipboard_history.json")
    }
    
    private init() {
        loadSettings()
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
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([ClipboardPreferenceRule].self, from: data) {
            self.customRules = decoded
        } else {
            // Default rules for password managers (set to Temporary by default)
            self.customRules = [
                ClipboardPreferenceRule(appName: "Keychain Access", ruleType: .temporary),
                ClipboardPreferenceRule(appName: "1Password", ruleType: .temporary),
                ClipboardPreferenceRule(appName: "Bitwarden", ruleType: .temporary)
            ]
        }
        
        let storedDuration = UserDefaults.standard.double(forKey: durationKey)
        if storedDuration > 0 {
            self.tempDuration = storedDuration
        } else {
            self.tempDuration = 60.0
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(customRules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
        UserDefaults.standard.set(tempDuration, forKey: durationKey)
    }
    
    func addRule(appName: String, ruleType: ClipboardPreferenceRule.RuleType) {
        customRules.removeAll(where: { $0.appName.lowercased() == appName.lowercased() })
        let newRule = ClipboardPreferenceRule(appName: appName, ruleType: ruleType)
        customRules.append(newRule)
        saveSettings()
    }
    
    func removeRule(id: UUID) {
        customRules.removeAll(where: { $0.id == id })
        saveSettings()
    }
    
    func updateRule(id: UUID, newType: ClipboardPreferenceRule.RuleType) {
        if let index = customRules.firstIndex(where: { $0.id == id }) {
            customRules[index].ruleType = newType
            saveSettings()
        }
    }
    
    private func checkExpiration() {
        let now = Date()
        let filtered = items.filter { item in
            if item.isTemporary, let expiry = item.expiresAt {
                return now < expiry
            }
            return true
        }
        
        if filtered.count != items.count {
            items = filtered
            saveHistory()
        }
    }
    
    private func checkPasteboard() {
        checkExpiration()
        
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let newText = pasteboard.string(forType: .string), !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if items.first?.text != newText {
                let activeApp = NSWorkspace.shared.frontmostApplication
                let appName = activeApp?.localizedName ?? "Unknown"
                
                let rule = customRules.first(where: { $0.appName.lowercased() == appName.lowercased() })?.ruleType ?? .save
                
                switch rule {
                case .ignore:
                    print("[ClipboardManager] Ignored copy from \(appName)")
                    return
                case .temporary:
                    let expires = Date().addingTimeInterval(tempDuration)
                    let newItem = ClipboardItem(
                        text: newText,
                        sourceApp: appName,
                        isTemporary: true,
                        expiresAt: expires
                    )
                    items.insert(newItem, at: 0)
                    if items.count > maxItems {
                        items = Array(items.prefix(maxItems))
                    }
                    saveHistory()
                    NotificationCenter.default.post(name: NSNotification.Name("ShowClipboardToast"), object: newItem)
                    
                case .save:
                    let newItem = ClipboardItem(
                        text: newText,
                        sourceApp: appName,
                        isTemporary: false,
                        expiresAt: nil
                    )
                    items.insert(newItem, at: 0)
                    if items.count > maxItems {
                        items = Array(items.prefix(maxItems))
                    }
                    saveHistory()
                    NotificationCenter.default.post(name: NSNotification.Name("ShowClipboardToast"), object: newItem)
                }
            }
        }
    }
    
    func makePermanent(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isTemporary = false
            items[index].expiresAt = nil
            saveHistory()
        }
    }
    
    func togglePin(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
            saveHistory()
        }
    }
    
    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
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
