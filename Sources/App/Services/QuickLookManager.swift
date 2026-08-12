import AppKit
import QuickLookUI
import Quartz

@MainActor
class QuickLookManager: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookManager()
    
    private var previewURLs: [URL] = []
    private var currentIndex: Int = 0
    
    override init() {
        super.init()
    }
    
    func togglePreview(urls: [URL], initialIndex: Int = 0) {
        guard !urls.isEmpty else { return }
        
        guard let panel = QLPreviewPanel.shared() else { return }
        
        if panel.isVisible && previewURLs == urls {
            panel.orderOut(nil)
            return
        }
        
        self.previewURLs = urls
        self.currentIndex = min(max(0, initialIndex), urls.count - 1)
        
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = self.currentIndex
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        HapticManager.shared.click()
    }
    
    func closePreview() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.orderOut(nil)
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return MainActor.assumeIsolated {
            QuickLookManager.shared.previewURLs.count
        }
    }
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return MainActor.assumeIsolated {
            guard index >= 0 && index < QuickLookManager.shared.previewURLs.count else {
                return nil
            }
            return QuickLookManager.shared.previewURLs[index] as NSURL
        }
    }
}
