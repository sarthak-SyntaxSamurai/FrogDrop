import AppKit
import PDFKit
import UserNotifications

@MainActor
class PDFToolkit {
    static let shared = PDFToolkit()
    
    private init() {}
    
    /// Merges multiple PDF files (or images) into a single PDF document
    func mergePDFs(urls: [URL]) async -> URL? {
        guard !urls.isEmpty else { return nil }
        
        let mergedDocument = PDFDocument()
        var pageIndex = 0
        
        for url in urls {
            if url.pathExtension.lowercased() == "pdf",
               let doc = PDFDocument(url: url) {
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i) {
                        mergedDocument.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            } else if let image = NSImage(contentsOf: url) {
                // If an image is dropped with PDFs, convert image to PDF page
                if let page = PDFPage(image: image) {
                    mergedDocument.insert(page, at: pageIndex)
                    pageIndex += 1
                }
            }
        }
        
        guard mergedDocument.pageCount > 0 else { return nil }
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let destURL = downloadsDir.appendingPathComponent("Merged_\(Int(Date().timeIntervalSince1970)).pdf")
        
        if mergedDocument.write(to: destURL) {
            HapticManager.shared.success()
            notifyUser(title: "PDFs Merged", body: "Combined \(pageIndex) pages into \(destURL.lastPathComponent)")
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
            return destURL
        }
        return nil
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
