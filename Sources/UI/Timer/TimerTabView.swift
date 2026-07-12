import SwiftUI
import AppKit

struct TimerTabView: View {
    @ObservedObject var timerManager = TimerManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if timerManager.isShowingSetup {
                TimerSetupView(timerManager: timerManager)
            } else {
                TodoListView()
                    .frame(maxHeight: 180)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 2)
                
                ScrollView {
                    VStack(spacing: 12) {
                        if timerManager.activeTimers.isEmpty {
                            StopwatchControlView(timerManager: timerManager)
                        } else {
                            ForEach(timerManager.activeTimers) { timer in
                                TugTimerCard(timer: timer, timerManager: timerManager)
                            }
                        }
                        
                        TimerHistoryListView()
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 4)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct StopwatchControlView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var taskName: String = ""
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Stopwatch Controls")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TextField("Stopwatch description...", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(isHovered ? 0.08 : 0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
                
                Button(action: {
                    timerManager.startStopwatch(name: taskName)
                    taskName = ""
                }) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

struct TugTimerCard: View {
    let timer: TimerManager.ActiveTimer
    @ObservedObject var timerManager: TimerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !timer.isStopwatch {
                        let endTime = Date().addingTimeInterval(timer.secondsRemaining)
                        Text("Ends at \(formatEndTime(endTime))")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Stopwatch Mode")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Text(formatTime(timer.isStopwatch ? timer.secondsElapsed : timer.secondsRemaining))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(timer.isBreakActive ? .orange : .green)
            }
            
            HStack(spacing: 8) {
                if !timer.isStopwatch {
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 1)
                    }) {
                        Text("+ 1m")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 5)
                    }) {
                        Text("+ 5m")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    timerManager.togglePause(timerId: timer.id)
                }) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    timerManager.stopTimer(timerId: timer.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Custom inline roller wheel picker mimicking iOS wheel picker layout
struct ScrollWheelPicker: View {
    let range: ClosedRange<Int>
    @Binding var selection: Int
    
    @State private var scrollSelection: Int?
    
    var body: some View {
        ZStack {
            // Highlight bands in center for selected item
            VStack(spacing: 0) {
                Divider()
                    .background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
                Spacer()
                Divider()
                    .background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
            }
            .frame(height: 24)
            .background(Color.white.opacity(0.03))
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { val in
                        Text(String(format: "%02d", val))
                            .font(.system(size: selection == val ? 15 : 12, weight: selection == val ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == val ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary.opacity(0.35))
                            .frame(height: 24)
                            .frame(maxWidth: .infinity)
                            .id(val)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                    scrollSelection = val
                                }
                                HapticManager.shared.click()
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollSelection)
            .safeAreaPadding(.vertical, 24)
            .frame(height: 72)
            .onAppear {
                scrollSelection = selection
            }
            .onChange(of: selection) { _, newValue in
                if scrollSelection != newValue {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        scrollSelection = newValue
                    }
                }
            }
            .onChange(of: scrollSelection) { _, newValue in
                if let newVal = newValue, selection != newVal {
                    selection = newVal
                    HapticManager.shared.tick()
                }
            }
        }
        .frame(width: 48, height: 72)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

struct TimerSetupView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var taskName: String = ""
    @State private var isPomodoro: Bool = false
    @State private var breakMinutes: Int = 5
    @State private var cycles: Int = 4
    @State private var isTaskHovered = false
    @State private var focusMinutes: Int = 25
    
    // Inline roller selection states
    @State private var setupHours: Int = 0
    @State private var setupMinutes: Int = 25
    
    private var totalDuration: TimeInterval {
        if isPomodoro {
            let focusTotal = timerManager.setupSeconds * Double(cycles)
            let breakTotal = Double(breakMinutes * 60) * Double(cycles - 1)
            return focusTotal + breakTotal
        } else {
            return timerManager.setupSeconds
        }
    }
    
    private var endTime: Date {
        Date().addingTimeInterval(totalDuration)
    }
    
    private func updateFromWheel() {
        var totalSecs = Double(setupHours * 3600 + setupMinutes * 60)
        if totalSecs < 60 {
            totalSecs = 60 // Minimum 1 minute
            setupMinutes = 1
        }
        timerManager.setupSeconds = totalSecs
        focusMinutes = Int(totalSecs / 60)
    }
    
    private func formatSummaryMinutes(_ totalMins: Int) -> String {
        let hrs = totalMins / 60
        let mins = totalMins % 60
        if hrs > 0 {
            if mins > 0 {
                return "\(hrs)h \(mins)m"
            } else {
                return "\(hrs)h"
            }
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                // Inline Hours & Minutes iOS Clock style roller wheel selectors
                HStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...6, selection: $setupHours)
                        Text("hours")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer().frame(width: 16)
                    
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...59, selection: $setupMinutes)
                        Text("min")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(height: 74)
                .padding(.top, 4)
                
                Text("Ends at \(formatEndTime(endTime))")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .onChange(of: setupHours) { _, _ in
                updateFromWheel()
            }
            .onChange(of: setupMinutes) { _, _ in
                updateFromWheel()
            }
            .onAppear {
                let totalSecs = timerManager.setupSeconds
                self.setupHours = Int(totalSecs) / 3600
                self.setupMinutes = (Int(totalSecs) % 3600) / 60
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("TASK NAME")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                
                TextField("What are you working on?", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(isTaskHovered ? 0.08 : 0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTaskHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .onHover { hovering in
                        isTaskHovered = hovering
                    }
            }
            .padding(.horizontal, 4)
            
            Toggle(isOn: $isPomodoro.animation(.spring(response: 0.3, dampingFraction: 0.7))) {
                Text("Pomodoro Mode")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.15, green: 0.85, blue: 0.45)))
            .padding(.horizontal, 4)
            
            if isPomodoro {
                VStack(spacing: 8) {
                    HStack {
                        Text("Break Duration")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $breakMinutes, in: 1...60) {
                            Text("\(breakMinutes) min")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack {
                        Text("Cycles")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $cycles, in: 2...12) {
                            Text("\(cycles)")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                    
                    // Self-calibrating cycle dots using dynamic width calculations to prevent window overflow
                    GeometryReader { geo in
                        let containerWidth = geo.size.width
                        let totalDots = cycles * 2 - 1
                        let spacing: CGFloat = 3
                        let totalSpacersWidth = CGFloat(totalDots - 1) * spacing
                        let remainingWidth = max(20, containerWidth - totalSpacersWidth)
                        let workCount = CGFloat(cycles)
                        let breakCount = CGFloat(cycles - 1)
                        let unitWidth = remainingWidth / (2 * workCount + breakCount)
                        let breakWidth = max(2, unitWidth)
                        let workWidth = max(4, unitWidth * 2)
                        
                        HStack(spacing: spacing) {
                            ForEach(0..<totalDots, id: \.self) { idx in
                                Capsule()
                                    .fill(idx % 2 == 0 ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.red.opacity(0.6))
                                    .frame(width: idx % 2 == 0 ? workWidth : breakWidth, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 6)
                    .padding(.top, 4)
                    
                    // Summary of total work and break times
                    HStack {
                        let totalWorkMins = (Int(timerManager.setupSeconds) / 60) * cycles
                        let totalBreakMins = breakMinutes * (cycles - 1)
                        
                        Text("Total Work: \(formatSummaryMinutes(totalWorkMins))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                        
                        Spacer()
                        
                        Text("Total Break: \(formatSummaryMinutes(totalBreakMins))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 2)
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    cancelSetup()
                }) {
                    Text("Cancel")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    startTimer()
                }) {
                    Text("Start")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 4)
            
            Text("Enter to start • Esc to cancel")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .onAppear {
            self.taskName = timerManager.setupTaskName
            self.focusMinutes = max(1, Int(timerManager.setupSeconds / 60))
        }
    }
    
    private func cancelSetup() {
        timerManager.isShowingSetup = false
        timerManager.setupTodoId = nil
    }
    
    private func startTimer() {
        if isPomodoro {
            timerManager.startPomodoro(
                taskName: taskName,
                focusDuration: timerManager.setupSeconds,
                breakDuration: TimeInterval(breakMinutes * 60),
                cycles: cycles,
                todoId: timerManager.setupTodoId
            )
        } else {
            timerManager.startTimer(
                duration: timerManager.setupSeconds,
                name: taskName,
                todoId: timerManager.setupTodoId
            )
        }
        timerManager.isShowingSetup = false
        timerManager.setupTodoId = nil
        if let delegate = NSApp.delegate as? AppDelegate { delegate.closeAllPanels() }
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimerHistoryListView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Focus History")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if !historyStore.history.isEmpty {
                    Button(action: {
                        historyStore.clearHistory()
                    }) {
                        Text("Clear")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            if historyStore.history.isEmpty {
                Text("No sessions logged yet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 5) {
                    ForEach(historyStore.history.prefix(5)) { session in
                        HStack {
                            Image(systemName: session.isPomodoro ? "flame.fill" : "timer")
                                .font(.system(size: 9))
                                .foregroundColor(session.isPomodoro ? .orange : .green)
                            
                            Text(session.name)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatDuration(session.duration))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(session.date))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct LargeEyeView: View {
    let mouseLocation: NSPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.85)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            
            Circle()
                .fill(Color.black)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 1.5, height: 1.5)
                        .offset(x: -1, y: -1)
                )
                .offset(pupilOffset())
        }
    }
    
    private func pupilOffset() -> CGSize {
        guard let delegate = NSApp.delegate as? AppDelegate,
              let popover = delegate.popupPopover,
              let window = popover.contentViewController?.view.window else {
            return .zero
        }
        
        let windowFrame = window.frame
        let absoluteCenter = NSPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )
        
        let dx = mouseLocation.x - absoluteCenter.x
        let dy = mouseLocation.y - absoluteCenter.y
        let distance = sqrt(dx*dx + dy*dy)
        
        guard distance > 0 else { return .zero }
        
        let maxOffset: CGFloat = 3.2
        let scale = min(distance / 250.0, 1.0) * maxOffset
        
        return CGSize(
            width: (dx / distance) * scale,
            height: -(dy / distance) * scale // Flip y-axis to match top-down layout coordinate space
        )
    }
}
