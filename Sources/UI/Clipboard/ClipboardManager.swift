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
    var text: String
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
    private var clipboardRetentionDays: Int {
        UserDefaults.standard.integer(forKey: "clipboardRetentionDays")
    }
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
        UserDefaults.standard.register(defaults: [
            "autoCleanURLs": false
        ])
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
    
    private func checkRetention() {
        guard clipboardRetentionDays > 0 else { return }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -clipboardRetentionDays, to: Date()) ?? Date()
        
        let originalCount = items.count
        items.removeAll { item in
            if item.isPinned { return false }
            return item.timestamp < cutoffDate
        }
        
        if items.count != originalCount {
            saveHistory()
        }
    }
    
    private func checkPasteboard() {
        checkExpiration()
        checkRetention()
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let newText = pasteboard.string(forType: .string), !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let activeApp = NSWorkspace.shared.frontmostApplication
            let appName = activeApp?.localizedName ?? "Unknown"
            
            let rule = customRules.first(where: { $0.appName.lowercased() == appName.lowercased() })?.ruleType ?? .save
            
            if rule == .ignore {
                print("[ClipboardManager] Ignored copy from \(appName)")
                return
            }
            
            var processedText = newText
            let autoClean = UserDefaults.standard.bool(forKey: "autoCleanURLs")
            if autoClean {
                let cleaned = cleanURL(newText)
                if cleaned != newText {
                    processedText = cleaned
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(cleaned, forType: .string)
                    lastChangeCount = pasteboard.changeCount
                }
            }
            
            let normalizedNewText = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let wasPinned = items.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNewText && $0.isPinned })
            items.removeAll(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNewText })
            
            let isTemp = (rule == .temporary)
            let expires = isTemp ? Date().addingTimeInterval(tempDuration) : nil
            
            let newItem = ClipboardItem(
                text: processedText,
                sourceApp: appName,
                isTemporary: isTemp,
                expiresAt: expires,
                isPinned: wasPinned
            )
            
            items.insert(newItem, at: 0)
            if items.count > maxItems {
                items = Array(items.prefix(maxItems))
            }
            saveHistory()
            NotificationCenter.default.post(name: NSNotification.Name("ShowClipboardToast"), object: newItem)
        }
    }
    
    func cleanURL(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased() else {
            return string
        }
        
        // 1. Amazon Rewriting
        if host.contains("amazon.") {
            let pattern = "/(dp|gp/product)/([A-Za-z0-9]{10})"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
                if let asinRange = Range(match.range(at: 2), in: trimmed) {
                    let asin = String(trimmed[asinRange])
                    return "https://\(host)/dp/\(asin)"
                }
            }
        }
        
        // 2. Flipkart Rewriting
        if host.contains("flipkart.com") {
            let pattern = "/p/([A-Za-z0-9]{10,20})"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
                if let idRange = Range(match.range(at: 1), in: trimmed) {
                    let productID = String(trimmed[idRange])
                    return "https://flipkart.com/p/\(productID)"
                }
            }
        }
        
        // 3. YouTube Rewriting
        if host.contains("youtube.com") || host.contains("youtu.be") {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                if host.contains("youtube.com") {
                    if let queryItems = components.queryItems,
                       let videoId = queryItems.first(where: { $0.name == "v" })?.value {
                        return "https://youtu.be/\(videoId)"
                    }
                    let pathParts = components.path.components(separatedBy: "/")
                    if pathParts.contains("shorts"), let videoId = pathParts.last, !videoId.isEmpty {
                        return "https://youtu.be/\(videoId)"
                    }
                } else if host.contains("youtu.be") {
                    let videoId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if !videoId.isEmpty {
                        return "https://youtu.be/\(videoId)"
                    }
                }
            }
        }
        
        // 4. Generic Tracking Parameter Cleaning
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems, !queryItems.isEmpty {
            let trackingKeys: Set<String> = [
                "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", 
                "utm_id", "utm_source_platform", "gclid", "fbclid", "msclkid", "twclid", 
                "igshid", "yclid", "li_fat_id", "srsltid", "ref", "ref_", "referrer", 
                "pid", "lid", "hl_lid", "marketplace", "fm", "pageUID", "sprefix"
            ]
            
            let cleanedItems = queryItems.filter { item in
                let key = item.name.lowercased()
                if trackingKeys.contains(key) { return false }
                if key.hasPrefix("pf_rd_") { return false }
                return true
            }
            
            var updatedComponents = components
            if cleanedItems.isEmpty {
                updatedComponents.queryItems = nil
            } else {
                updatedComponents.queryItems = cleanedItems
            }
            
            if let cleanedString = updatedComponents.url?.absoluteString {
                return cleanedString
            }
        }
        
        return string
    }
    
    func updateText(_ item: ClipboardItem, newText: String) {
        guard let originalIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let normalizedNewText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if normalizedNewText.isEmpty {
            return
        }
        
        items[originalIndex].text = newText
        
        let matchingIndices = items.indices.filter { items[$0].text.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedNewText }
        
        if matchingIndices.count > 1 {
            let anyPinned = matchingIndices.contains { items[$0].isPinned }
            let firstMatchIndex = matchingIndices.first!
            
            items[firstMatchIndex].isPinned = anyPinned
            
            for index in matchingIndices.dropFirst().reversed() {
                items.remove(at: index)
            }
        }
        
        saveHistory()
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
