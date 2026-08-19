import AppKit
import ImageIO
import UniformTypeIdentifiers
import UserNotifications

@MainActor
class ImageOptimizer {
    static let shared = ImageOptimizer()
    
    private init() {}
    
    /// Converts images to Web format (AVIF / Web-optimized) and saves to Downloads
    func convertToWebP(urls: [URL]) async -> [URL] {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        var results: [URL] = []
        
        for url in urls {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }
            
            let baseName = url.deletingPathExtension().lastPathComponent
            
            // Try AVIF first (next-gen web format, 20% smaller than WebP, supported natively by macOS & all modern browsers)
            let avifURL = downloadsDir.appendingPathComponent("\(baseName).avif")
            if let destination = CGImageDestinationCreateWithURL(avifURL as CFURL, "public.avif" as CFString, 1, nil) {
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.8
                ]
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    results.append(avifURL)
                    continue
                }
            }
            
            // Fallback to high-efficiency Web-optimized JPEG
            let webpFallbackURL = downloadsDir.appendingPathComponent("\(baseName)_web.jpg")
            if let destination = CGImageDestinationCreateWithURL(webpFallbackURL as CFURL, "public.jpeg" as CFString, 1, nil) {
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.75
                ]
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    results.append(webpFallbackURL)
                }
            }
        }
        
        if !results.isEmpty {
            HapticManager.shared.success()
            notifyUser(title: String(
                localized: "image-optimizer.web-conversion.title",
                defaultValue: "Converted to Web Format",
                comment: "Title for notification after converting images to web format"
            ), body: String(format: String(
                localized: "image-optimizer.web-conversion.saved-summary",
                defaultValue: "%d image(s) saved to Downloads.",
                comment: "Summary for notification showing how many images were saved after web conversion"
            ), results.count))
            NSWorkspace.shared.activateFileViewerSelecting(results)
        }
        return results
    }
    
    /// Compresses images and reduces file size by 60-80%
    func compressImages(urls: [URL], quality: CGFloat = 0.7) async -> [URL] {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        var results: [URL] = []
        
        for url in urls {
            guard let image = NSImage(contentsOf: url),
                  let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData) else {
                continue
            }
            
            let baseName = url.deletingPathExtension().lastPathComponent
            let destURL = downloadsDir.appendingPathComponent("\(baseName)_compressed.jpg")
            
            let compressionProps: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: quality
            ]
            
            if let compressedData = bitmapRep.representation(using: .jpeg, properties: compressionProps) {
                do {
                    try compressedData.write(to: destURL)
                    results.append(destURL)
                } catch {
                    print("[ImageOptimizer] Failed to save compressed image: \(error)")
                }
            }
        }
        
        if !results.isEmpty {
            HapticManager.shared.success()
            notifyUser(title: String(
                localized: "image-optimizer.compression.title",
                defaultValue: "Images Compressed",
                comment: "Title for notification after compressing images"
            ), body: String(format: String(
                localized: "image-optimizer.compression.saved-summary",
                defaultValue: "%d image(s) compressed & saved to Downloads.",
                comment: "Summary for notification showing how many images were compressed and saved"
            ), results.count))
            NSWorkspace.shared.activateFileViewerSelecting(results)
        }
        return results
    }
    
    /// Strips EXIF GPS coordinates and camera metadata for sharing privacy
    func stripMetadata(urls: [URL]) async -> [URL] {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        var results: [URL] = []
        
        for url in urls {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }
            
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let baseName = url.deletingPathExtension().lastPathComponent
            let destURL = downloadsDir.appendingPathComponent("\(baseName)_clean.\(ext)")
            
            let uti = (UTType(filenameExtension: ext) ?? .jpeg).identifier as CFString
            guard let destination = CGImageDestinationCreateWithURL(destURL as CFURL, uti, 1, nil) else {
                continue
            }
            
            // Adding image without metadata dictionary strips all EXIF/GPS tags
            CGImageDestinationAddImage(destination, cgImage, nil)
            if CGImageDestinationFinalize(destination) {
                results.append(destURL)
            }
        }
        
        if !results.isEmpty {
            HapticManager.shared.success()
            notifyUser(title: String(
                localized: "image-optimizer.metadata-strip.title",
                defaultValue: "Metadata Stripped",
                comment: "Title for notification after removing metadata"
            ), body: String(
                localized: "image-optimizer.metadata-strip.summary",
                defaultValue: "EXIF & GPS location removed. Saved to Downloads.",
                comment: "Summary for notification after removing EXIF and GPS metadata"
            ))
            NSWorkspace.shared.activateFileViewerSelecting(results)
        }
        return results
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
