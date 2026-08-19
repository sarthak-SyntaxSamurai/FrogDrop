import SwiftUI
import AppKit

struct TimerTabView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var gamification = FocusGamificationManager.shared
    @ObservedObject var ambientSound = AmbientSoundManager.shared
    @ObservedObject var pillManager = FloatingFocusPillManager.shared
    
    @State private var taskIntent: String = ""
    @State private var isTaskHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            if timerManager.isShowingSetup {
                TimerSetupView(timerManager: timerManager)
            } else {
                // 1. Gamification & Streak Header
                FocusGamificationHeaderView(gamification: gamification, pillManager: pillManager)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 1)
                
                ScrollView {
                    VStack(spacing: 12) {
                        // 2. Active Timer Ring OR Quick Presets
                        if let activeTimer = timerManager.activeTimers.first {
                            CircularFocusTimerCard(timer: activeTimer, timerManager: timerManager)
                        } else {
                            VStack(spacing: 10) {
                                // Task Intent Input
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.and.outline")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                    
                                    TextField(String(localized: "timer.tab.focus-input.placeholder", defaultValue: "What are you focusing on?", comment: "Placeholder text for focus task input field"), text: $taskIntent)
                                        .textFieldStyle(.plain)
                                        .font(.system(.subheadline, design: .rounded))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(isTaskHovered ? 0.08 : 0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isTaskHovered ? Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                                .onHover { hovering in
                                    isTaskHovered = hovering
                                }
                                
                                // Quick Presets Grid
                                QuickPresetsGrid(timerManager: timerManager, taskName: taskIntent)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                        
                        // 3. Ambient Focus Soundscapes
                        AmbientSoundControlCard(ambientSound: ambientSound)
                        
                        // 4. Todo Task List
                        TodoListView()
                            .frame(maxHeight: 160)
                        
                        // 5. Session History
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

// MARK: - Gamification Header

struct FocusGamificationHeaderView: View {
    @ObservedObject var gamification: FocusGamificationManager
    @ObservedObject var pillManager: FloatingFocusPillManager
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Streak Badge
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 11))
                    Text(String(format: String(localized: "timer.tab.gamification.streak-days", defaultValue: "%dd streak", comment: "Streak label showing number of consecutive days"), gamification.streakDays))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
                .overlay(Capsule().stroke(Color.orange.opacity(0.25), lineWidth: 0.5))
                
                // Golden Flies Badge
                HStack(spacing: 3) {
                    Text("🪰")
                        .font(.system(size: 10))
                    Text(String(format: String(localized: "timer.tab.gamification.golden-flies-count", defaultValue: "%d", comment: "Displayed count of earned golden flies"), gamification.goldenFlies))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.yellow.opacity(0.12)))
                .overlay(Capsule().stroke(Color.yellow.opacity(0.25), lineWidth: 0.5))
                
                // Frog Evolution Stage
                HStack(spacing: 3) {
                    Image(systemName: gamification.currentStage.icon)
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                    Text(gamification.currentStage.title)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.1)))
                
                Spacer()
                
                // Floating HUD Pill Toggle Button
                Button(action: {
                    pillManager.toggle()
                    HapticManager.shared.click()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pip.fill")
                            .font(.system(size: 8))
                        Text(pillManager.isVisible ? String(localized: "timer.tab.hud.toggle.on", defaultValue: "HUD On", comment: "Label for HUD enabled state") : String(localized: "timer.tab.hud.toggle.off", defaultValue: "HUD", comment: "Label for HUD disabled state"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(pillManager.isVisible ? .black : .white.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(pillManager.isVisible ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.white.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Daily Progress Bar
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(gamification.dailyProgress), height: 4)
                    }
                }
                .frame(height: 4)
                
                Text(String(format: String(localized: "timer.tab.daily-goal.progress-minutes", defaultValue: "%d/%dm", comment: "Daily goal progress showing elapsed and target minutes"), gamification.totalMinutesToday, gamification.dailyGoalMinutes))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

// MARK: - Circular Focus Timer Card

struct CircularFocusTimerCard: View {
    let timer: TimerManager.ActiveTimer
    @ObservedObject var timerManager: TimerManager
    
    private var progress: Double {
        if timer.isStopwatch { return 1.0 }
        guard timer.totalSeconds > 0 else { return 0 }
        return 1.0 - (timer.secondsRemaining / timer.totalSeconds)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Animated Progress Ring
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.001, progress)))
                    .stroke(
                        LinearGradient(
                            colors: timer.isBreakActive ?
                                [Color.orange, Color.yellow] :
                                [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                
                // Center Display
                VStack(spacing: 2) {
                    Text(timer.isBreakActive ? String(localized: "timer.tab.mode.break", defaultValue: "☕ Break", comment: "Mode label for break session preset") : String(localized: "timer.tab.mode.focus", defaultValue: "🐸 Focus", comment: "Mode label for focus session preset"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(timer.isBreakActive ? .orange : Color(red: 0.15, green: 0.85, blue: 0.45))
                    
                    Text(formatTime(timer.isStopwatch ? timer.secondsElapsed : timer.secondsRemaining))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(timer.name)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 90)
                }
            }
            .padding(.top, 4)
            
            // Interactive Controls
            HStack(spacing: 8) {
                if !timer.isStopwatch {
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 1)
                    }) {
                        Text(String(localized: "timer.tab.adjust-time.plus-one-minute", defaultValue: "+1m", comment: "Button label to add one minute"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 5)
                    }) {
                        Text(String(localized: "timer.tab.adjust-time.plus-five-minutes", defaultValue: "+5m", comment: "Button label to add five minutes"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
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
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    timerManager.stopTimer(timerId: timer.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
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
}

// MARK: - Quick Presets Grid

struct QuickPresetsGrid: View {
    @ObservedObject var timerManager: TimerManager
    let taskName: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                FocusPresetChip(title: String(localized: "timer.tab.preset.pomodoro.twenty-five-minutes", defaultValue: "25m Pomodoro", comment: "Timer preset label for 25 minute Pomodoro session"), icon: "flame.fill", color: Color.green) {
                    timerManager.startPomodoroPreset(taskName: taskName.isEmpty ? String(localized: "timer.tab.preset.pomodoro.title", defaultValue: "Pomodoro", comment: "Short preset title for Pomodoro mode") : taskName)
                }
                
                FocusPresetChip(title: String(localized: "timer.tab.preset.deep-work.fifty-minutes", defaultValue: "50m Deep Work", comment: "Timer preset label for 50 minute deep work session"), icon: "brain.head.profile", color: Color.teal) {
                    timerManager.startDeepWorkPreset(taskName: taskName.isEmpty ? String(localized: "timer.tab.preset.deep-work.title", defaultValue: "Deep Work", comment: "Short preset title for deep work mode") : taskName)
                }
            }
            
            HStack(spacing: 6) {
                FocusPresetChip(title: String(localized: "timer.tab.preset.sprint.fifteen-minutes", defaultValue: "15m Sprint", comment: "Timer preset label for 15 minute sprint session"), icon: "bolt.fill", color: Color.yellow) {
                    timerManager.startSprintPreset(taskName: taskName.isEmpty ? String(localized: "timer.tab.preset.sprint.title", defaultValue: "Sprint", comment: "Short preset title for sprint mode") : taskName)
                }
                
                FocusPresetChip(title: String(localized: "timer.tab.preset.break.five-minutes", defaultValue: "5m Break", comment: "Timer preset label for 5 minute break session"), icon: "cup.and.saucer.fill", color: Color.orange) {
                    timerManager.startQuickBreakPreset()
                }
                
                FocusPresetChip(title: String(localized: "timer.tab.preset.stopwatch.title", defaultValue: "Stopwatch", comment: "Preset title for stopwatch mode"), icon: "stopwatch.fill", color: Color.blue) {
                    timerManager.startStopwatch(name: taskName.isEmpty ? String(localized: "timer.tab.preset.flow.title", defaultValue: "Flow", comment: "Preset title for flow mode") : taskName)
                }
            }
        }
    }
}

struct FocusPresetChip: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.click()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.white.opacity(isHovered ? 0.08 : 0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? color.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Ambient Soundscape Card

struct AmbientSoundControlCard: View {
    @ObservedObject var ambientSound: AmbientSoundManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "headphones")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                    Text(String(localized: "timer.tab.ambient-audio.section-title", defaultValue: "AMBIENT FOCUS AUDIO", comment: "Section header for ambient focus audio controls"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                }
                
                Spacer()
                
                if ambientSound.activeSound != .none {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $ambientSound.volume, in: 0...1)
                            .frame(width: 60)
                            .accentColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                    }
                }
            }
            
            // Sound Selector Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AmbientSoundType.allCases) { sound in
                        let isSelected = ambientSound.activeSound == sound
                        Button(action: {
                            ambientSound.selectSound(sound)
                            HapticManager.shared.click()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: sound.icon)
                                    .font(.system(size: 8))
                                Text(sound.rawValue)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                            }
                            .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(isSelected ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Legacy Preserved Components

struct ScrollWheelPicker: View {
    let range: ClosedRange<Int>
    @Binding var selection: Int
    @State private var scrollSelection: Int?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Divider().background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
                Spacer()
                Divider().background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
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
            totalSecs = 60
            setupMinutes = 1
        }
        timerManager.setupSeconds = totalSecs
        focusMinutes = Int(totalSecs / 60)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...6, selection: $setupHours)
                        Text(String(localized: "timer.tab.custom-duration.hours-label", defaultValue: "hours", comment: "Unit label for hour input in custom timer settings"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer().frame(width: 16)
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...59, selection: $setupMinutes)
                        Text(String(localized: "timer.tab.custom-duration.minutes-label", defaultValue: "min", comment: "Unit label for minute input in custom timer settings"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 74)
                .padding(.top, 4)
                
                Text(String(format: String(localized: "timer.tab.session.ends-at-time", defaultValue: "Ends at %@", comment: "Label showing session end time"), "\(formatEndTime(endTime))"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .onChange(of: setupHours) { _, _ in updateFromWheel() }
            .onChange(of: setupMinutes) { _, _ in updateFromWheel() }
            .onAppear {
                let totalSecs = timerManager.setupSeconds
                self.setupHours = Int(totalSecs) / 3600
                self.setupMinutes = (Int(totalSecs) % 3600) / 60
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "timer.tab.task-name.section-title", defaultValue: "TASK NAME", comment: "Section header for task name input"))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                
                TextField(String(localized: "timer.tab.task-name.placeholder", defaultValue: "What are you working on?", comment: "Placeholder for task name input field"), text: $taskName)
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
                    .onHover { isTaskHovered = $0 }
            }
            .padding(.horizontal, 4)
            
            Toggle(isOn: $isPomodoro.animation(.spring(response: 0.3, dampingFraction: 0.7))) {
                Text(String(localized: "timer.tab.pomodoro.mode.label", defaultValue: "Pomodoro Mode", comment: "Label for pomodoro mode toggle"))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.15, green: 0.85, blue: 0.45)))
            .padding(.horizontal, 4)
            
            if isPomodoro {
                VStack(spacing: 8) {
                    HStack {
                        Text(String(localized: "timer.tab.pomodoro.break-duration.label", defaultValue: "Break Duration", comment: "Label for configuring pomodoro break duration"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $breakMinutes, in: 1...60) {
                            Text(String(format: String(localized: "timer.tab.pomodoro.break-duration.value", defaultValue: "%d min", comment: "Displayed pomodoro break duration in minutes"), breakMinutes))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack {
                        Text(String(localized: "timer.tab.pomodoro.cycles.label", defaultValue: "Cycles", comment: "Label for number of pomodoro cycles"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $cycles, in: 2...12) {
                            Text(String(format: String(localized: "timer.tab.pomodoro.cycles.value", defaultValue: "%d", comment: "Displayed number of configured pomodoro cycles"), cycles))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                .padding(.horizontal, 4)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(String(localized: "timer.tab.session-setup.cancel", defaultValue: "Cancel", comment: "Cancel button title in timer setup panel")) {
                    cancelSetup()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button(action: {
                    startTimer()
                }) {
                    Text(String(localized: "timer.tab.session-setup.start-focus", defaultValue: "Start Focus", comment: "Primary button title to start focus session"))
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
            }
            .padding(.bottom, 4)
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
                Text(String(localized: "timer.tab.history.title", defaultValue: "Focus History", comment: "Title for focus session history section"))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if !historyStore.history.isEmpty {
                    Button(action: {
                        historyStore.clearHistory()
                    }) {
                        Text(String(localized: "timer.tab.history.clear", defaultValue: "Clear", comment: "Button title to clear focus history"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            if historyStore.history.isEmpty {
                Text(String(localized: "timer.tab.history.empty-state", defaultValue: "No sessions logged yet", comment: "Empty state text when no focus sessions are logged"))
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
            return String(format: String(localized: "timer.tab.history.duration.minutes", defaultValue: "%dm", comment: "Session duration text showing whole minutes"), mins)
        } else {
            return String(format: String(localized: "timer.tab.history.duration.seconds", defaultValue: "%ds", comment: "Session duration text showing seconds when under a minute"), secs)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
