import AppKit
import QuickLookThumbnailing

enum TaskProgressState: Equatable {
    case idle
    case running(String)
    case success(String)
    case failure(String)
}

struct ShelfGroup: Identifiable {
    let id = UUID()
    var files: [URL]
    var thumbnails: [URL: NSImage] = [:]
    
    static func generateThumb(for url: URL) async -> NSImage? {
        let size = CGSize(width: 80, height: 80)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: NSScreen.main?.backingScaleFactor ?? 2.0, representationTypes: .thumbnail)
        
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            let exts = ["jpg","jpeg","png","gif","heic","heif","tiff","bmp","webp","pdf"]
            guard exts.contains(url.pathExtension.lowercased()),
                  let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 80] as CFDictionary)
            else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: 40, height: 40))
        }
    }
}
