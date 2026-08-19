import AppKit
import SwiftUI
import UserNotifications

@MainActor
class ScreenColorSampler {
    static let shared = ScreenColorSampler()
    
    private init() {}
    
    /// Opens the native macOS loupe eyedropper and samples a color from the screen
    func sampleColor() async -> String? {
        let sampler = NSColorSampler()
        guard let selectedColor = await sampler.sample() else {
            return nil
        }
        
        guard let rgbColor = selectedColor.usingColorSpace(.sRGB) else {
            return nil
        }
        
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))
        
        let hexString = String(format: "#%02X%02X%02X", red, green, blue)
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(hexString, forType: .string)
        
        HapticManager.shared.success()
        notifyUser(
            title: String(localized: "screen-color-sampler.color-picked.title", defaultValue: "Color Picked", bundle: .main, comment: "Notification subtitle when a screen color is sampled"),
            body: String(format: String(localized: "screen-color-sampler.color-picked.body", defaultValue: "%@ copied to clipboard!", bundle: .main, comment: "Notification body showing copied hex color"), hexString)
        )
        
        return hexString
    }
    
    private func notifyUser(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "FrogDrop"
        content.subtitle = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        if Bundle.main.bundleIdentifier != nil {
            Task { try? await UNUserNotificationCenter.current().add(request) }
        }
    }
}
