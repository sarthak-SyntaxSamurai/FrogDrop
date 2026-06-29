import Foundation
import UserNotifications
import AppKit

@MainActor
class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    enum TimerState: String, Codable {
        case idle
        case running
        case paused
    }
    
    var state: TimerState {
        if activeTimers.isEmpty {
            return .idle
        } else if activeTimers.contains(where: { $0.state == .running }) {
            return .running
        } else {
            return .paused
        }
    }
    
    struct ActiveTimer: Identifiable, Codable {
        let id: UUID
        var todoId: UUID?
        var name: String
        var totalSeconds: TimeInterval // 0 for stopwatch
        var secondsRemaining: TimeInterval
        var secondsElapsed: TimeInterval
        var state: TimerState
        var isStopwatch: Bool
        
        // Pomodoro specific fields
        var isPomodoro: Bool = false
        var currentCycle: Int = 1
        var totalCycles: Int = 4
        var isBreakActive: Bool = false
        var breakDuration: TimeInterval = 5 * 60
        var focusDuration: TimeInterval = 25 * 60
    }
    
    @Published var activeTimers: [ActiveTimer] = []
    @Published var isWinking: Bool = false
    
    // Setup state (preloaded from drag-right or todo play button click)
    @Published var isShowingSetup: Bool = false
    @Published var setupSeconds: TimeInterval = 0
    @Published var setupTaskName: String = ""
    @Published var setupTodoId: UUID? = nil
    @Published var setupIsPomodoro: Bool = false
    @Published var setupBreakMinutes: Int = 5
    @Published var setupCycles: Int = 4
    
    private var masterTimer: Timer?
    
    private init() {
        requestNotificationPermission()
        startMasterTimer()
    }
    
    private func startMasterTimer() {
        masterTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard !activeTimers.isEmpty else {
            updateMenuBar()
            return
        }
        
        var timersChanged = false
        var updatedTimers: [ActiveTimer] = []
        
        for var timer in activeTimers {
            if timer.state == .running {
                timersChanged = true
                if timer.isStopwatch {
                    timer.secondsElapsed += 1
                    if let todoId = timer.todoId {
                        TodoManager.shared.addDuration(id: todoId, seconds: 1)
                    }
                    updatedTimers.append(timer)
                } else {
                    if timer.secondsRemaining > 0 {
                        timer.secondsRemaining -= 1
                        if let todoId = timer.todoId, !timer.isBreakActive {
                            TodoManager.shared.addDuration(id: todoId, seconds: 1)
                        }
                        updatedTimers.append(timer)
                    } else {
                        // Timer completed
                        sessionCompleted(for: &timer, updatedTimers: &updatedTimers)
                    }
                }
            } else {
                updatedTimers.append(timer)
            }
        }
        
        activeTimers = updatedTimers
        if timersChanged {
            updateMenuBar()
        }
    }
    
    private func sessionCompleted(for timer: inout ActiveTimer, updatedTimers: inout [ActiveTimer]) {
        HapticManager.shared.success()
        NSSound(named: "Glass")?.play()
        
        if timer.isPomodoro {
            if !timer.isBreakActive {
                // Focus session finished
                HistoryStore.shared.logSession(name: timer.name, duration: timer.focusDuration, isPomodoro: true)
                
                if timer.currentCycle < timer.totalCycles {
                    // Switch to Break
                    timer.isBreakActive = true
                    timer.secondsRemaining = timer.breakDuration
                    timer.totalSeconds = timer.breakDuration
                    sendSessionCompleteNotification(title: "Focus Session Finished!", body: "Time for a \(Int(timer.breakDuration / 60)) min break.")
                    updatedTimers.append(timer)
                } else {
                    // All cycles finished
                    sendSessionCompleteNotification(title: "Pomodoro Finished!", body: "Great job! All \(timer.totalCycles) cycles completed.")
                }
            } else {
                // Break session finished
                timer.isBreakActive = false
                timer.currentCycle += 1
                timer.secondsRemaining = timer.focusDuration
                timer.totalSeconds = timer.focusDuration
                sendSessionCompleteNotification(title: "Break Finished!", body: "Time to focus on: \(timer.name). Cycle \(timer.currentCycle) of \(timer.totalCycles).")
                updatedTimers.append(timer)
            }
        } else {
            // Regular timer finished
            HistoryStore.shared.logSession(name: timer.name, duration: timer.totalSeconds, isPomodoro: false)
            sendSessionCompleteNotification(title: "Timer Finished!", body: "Your timer for \"\(timer.name)\" has completed.")
        }
    }
    
    // MARK: - Actions
    
    private func triggerWink() {
        self.isWinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isWinking = false
        }
    }
    
    func startTimer(duration: TimeInterval, name: String = "Timer", todoId: UUID? = nil) {
        let newTimer = ActiveTimer(
            id: UUID(),
            todoId: todoId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Timer" : name,
            totalSeconds: duration,
            secondsRemaining: duration,
            secondsElapsed: 0,
            state: .running,
            isStopwatch: false
        )
        activeTimers.append(newTimer)
        HapticManager.shared.click()
        sendSessionStartNotification(for: newTimer)
        updateMenuBar()
        triggerWink()
    }
    
    func startStopwatch(name: String, todoId: UUID? = nil) {
        let newTimer = ActiveTimer(
            id: UUID(),
            todoId: todoId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Stopwatch" : name,
            totalSeconds: 0,
            secondsRemaining: 0,
            secondsElapsed: 0,
            state: .running,
            isStopwatch: true
        )
        activeTimers.append(newTimer)
        HapticManager.shared.click()
        sendSessionStartNotification(for: newTimer)
        updateMenuBar()
        triggerWink()
    }
    
    func startPomodoro(taskName: String, focusDuration: TimeInterval, breakDuration: TimeInterval, cycles: Int, todoId: UUID? = nil) {
        let name = taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus Session" : taskName
        let newTimer = ActiveTimer(
            id: UUID(),
            todoId: todoId,
            name: name,
            totalSeconds: focusDuration,
            secondsRemaining: focusDuration,
            secondsElapsed: 0,
            state: .running,
            isStopwatch: false,
            isPomodoro: true,
            currentCycle: 1,
            totalCycles: cycles,
            isBreakActive: false,
            breakDuration: breakDuration,
            focusDuration: focusDuration
        )
        activeTimers.append(newTimer)
        HapticManager.shared.click()
        sendSessionStartNotification(for: newTimer)
        updateMenuBar()
        triggerWink()
    }
    
    func addTime(timerId: UUID, minutes: TimeInterval) {
        if let idx = activeTimers.firstIndex(where: { $0.id == timerId }) {
            activeTimers[idx].secondsRemaining += minutes * 60
            activeTimers[idx].totalSeconds += minutes * 60
            HapticManager.shared.click()
        }
    }
    
    func togglePause(timerId: UUID) {
        if let idx = activeTimers.firstIndex(where: { $0.id == timerId }) {
            if activeTimers[idx].state == .running {
                activeTimers[idx].state = .paused
            } else {
                activeTimers[idx].state = .running
            }
            HapticManager.shared.click()
            updateMenuBar()
        }
    }
    
    func stopTimer(timerId: UUID) {
        if let idx = activeTimers.firstIndex(where: { $0.id == timerId }) {
            let timer = activeTimers[idx]
            if timer.isStopwatch && timer.secondsElapsed >= 5 {
                HistoryStore.shared.logSession(name: timer.name, duration: timer.secondsElapsed, isPomodoro: false)
            }
        }
        activeTimers.removeAll { $0.id == timerId }
        HapticManager.shared.click()
        updateMenuBar()
    }
    
    // MARK: - Menu Bar helpers
    
    func getFirstActiveTimer() -> ActiveTimer? {
        return activeTimers.first { $0.state == .running } ?? activeTimers.first
    }
    
    func getFormattedMenuBarTime() -> String {
        guard let timer = getFirstActiveTimer() else { return "" }
        let seconds = timer.isStopwatch ? timer.secondsElapsed : timer.secondsRemaining
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func updateMenuBar() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateMenuBarTitle()
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func sendSessionStartNotification(for timer: ActiveTimer) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        if timer.isStopwatch {
            content.title = "Stopwatch Started"
            content.body = "Tracking time for: \(timer.name)"
        } else if timer.isPomodoro {
            content.title = timer.isBreakActive ? "Break Time!" : "Focus Time!"
            content.body = timer.isBreakActive ? "Take a breath. Break for \(Int(timer.breakDuration / 60)) mins." : "Focusing on: \(timer.name). Cycle \(timer.currentCycle) of \(timer.totalCycles)."
        } else {
            content.title = "Timer Started"
            content.body = "Timer set for \(Int(timer.totalSeconds / 60)) mins."
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func sendSessionCompleteNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
