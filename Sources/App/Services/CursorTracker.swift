import AppKit
import Foundation

@MainActor
class CursorTracker: ObservableObject {
    static let shared = CursorTracker()
    
    @Published var mouseLocation: NSPoint = .zero
    
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    
    deinit {
        timer?.invalidate()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private init() {
        updateTrackingState()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateTrackingState() }
        }
    }
    
    private func updateTrackingState() {
        let style = UserDefaults.standard.string(forKey: "menuBarIconStyle") ?? "frog"
        if style == "frog" {
            if timer == nil { startTracking() }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.mouseLocation = NSEvent.mouseLocation
            }
        }
    }
}
