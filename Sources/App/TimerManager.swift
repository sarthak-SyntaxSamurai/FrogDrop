import Foundation
import UserNotifications
import AppKit

@MainActor
class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    enum TimerState {
        case idle
        case running
        case paused
    }
    
    @Published var state: TimerState = .idle
    @Published var totalSeconds: TimeInterval = 0
    @Published var secondsRemaining: TimeInterval = 0
    
    private var timer: Timer?
    
    private init() {
        requestNotificationPermission()
    }
    
    func startTimer(duration: TimeInterval) {
        stopTimer()
        
        self.totalSeconds = duration
        self.secondsRemaining = duration
        self.state = .running
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        
        HapticManager.shared.click()
    }
    
    func togglePause() {
        switch state {
        case .running:
            state = .paused
            timer?.invalidate()
            timer = nil
        case .paused:
            state = .running
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
        default:
            break
        }
        HapticManager.shared.click()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        state = .idle
        secondsRemaining = 0
        totalSeconds = 0
    }
    
    private func tick() {
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            timerCompleted()
        }
    }
    
    private func timerCompleted() {
        stopTimer()
        HapticManager.shared.success()
        sendCompletionNotification()
        
        // Play system notification sound
        NSSound(named: "Glass")?.play()
    }
    
    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("Notifications disabled: Running as a raw CLI binary (requires .app bundle).")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func sendCompletionNotification() {
        guard Bundle.main.bundleIdentifier != nil else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished!"
        content.body = "Your FrogDrop timer has completed."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
