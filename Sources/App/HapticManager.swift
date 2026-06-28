import AppKit

class HapticManager {
    static let shared = HapticManager()
    
    enum HapticLevel: String, Codable, CaseIterable {
        case off = "Off"
        case soft = "Soft"
        case medium = "Medium"
        case strong = "Strong"
    }
    
    private let hapticKey = "frogdrop.hapticLevel"
    
    var level: HapticLevel {
        get {
            if let stored = UserDefaults.standard.string(forKey: hapticKey),
               let parsed = HapticLevel(rawValue: stored) {
                return parsed
            }
            return .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: hapticKey)
        }
    }
    
    private init() {}
    
    func tick() {
        guard level != .off else { return }
        switch level {
        case .soft:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .medium:
            // Medium tick is generic click so it is easily felt
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .strong:
            // Strong tick uses level change for high tactility
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .off:
            break
        }
    }
    
    func click() {
        guard level != .off else { return }
        switch level {
        case .soft:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .medium:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .strong:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .off:
            break
        }
    }
    
    func success() {
        guard level != .off else { return }
        switch level {
        case .soft:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .medium:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .strong:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        case .off:
            break
        }
    }
}
