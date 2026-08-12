import AppKit
@preconcurrency import Vision
import UserNotifications

@MainActor
class OCRManager {
    static let shared = OCRManager()
    
    private init() {}
    
    /// Extracts text from a list of image or PDF file URLs
    func extractText(from urls: [URL]) async -> String? {
        var combinedText: [String] = []
        
        for url in urls {
            if let image = NSImage(contentsOf: url),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                if let text = await recognizeText(in: cgImage), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    combinedText.append("--- \(url.lastPathComponent) ---\n\(text)")
                }
            }
        }
        
        guard !combinedText.isEmpty else { return nil }
        let result = combinedText.joined(separator: "\n\n")
        
        // Copy to Pasteboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(result, forType: .string)
        
        HapticManager.shared.success()
        notifyUser(title: "Text Extracted (OCR)", body: "\(combinedText.count) image(s) processed. Text copied to clipboard!")
        return result
    }
    
    /// Extracts text from clipboard image if present
    func extractTextFromClipboard() async -> String? {
        let pb = NSPasteboard.general
        guard let image = NSImage(pasteboard: pb),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        guard let text = await recognizeText(in: cgImage), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        pb.clearContents()
        pb.setString(text, forType: .string)
        
        HapticManager.shared.success()
        notifyUser(title: "Text Extracted (OCR)", body: "Extracted text copied to clipboard!")
        return text
    }
    
    private func recognizeText(in cgImage: CGImage) async -> String? {
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let observations = request.results else { return nil }
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                return recognizedStrings.joined(separator: "\n")
            } catch {
                return nil
            }
        }.value
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
