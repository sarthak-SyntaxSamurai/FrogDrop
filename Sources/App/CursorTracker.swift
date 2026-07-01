import AppKit
import Foundation

@MainActor
class CursorTracker: ObservableObject {
    static let shared = CursorTracker()
    
    @Published var mouseLocation: NSPoint = .zero
    
    private var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    private init() {
        startTracking()
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.mouseLocation = NSEvent.mouseLocation
            }
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
}
