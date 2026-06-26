import AppKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// A subtle tick, useful for drag increments (like tongue stretching)
    func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    /// A standard click feedback
    func click() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    /// Stronger feedback for actions like timer completion or file drop
    func success() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
