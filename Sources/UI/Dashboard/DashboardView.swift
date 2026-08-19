import SwiftUI

struct DashboardView: View {
    @AppStorage("dailyFocusGoal") var dailyFocusGoal: Int = 120
    @Binding var activeTab: MainSidebarView.Tab
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var todoManager = TodoManager.shared
    @ObservedObject var historyStore = HistoryStore.shared
    
    @State private var isPlayHovered = false
    @State private var frogScale: CGFloat = 1.0
    
    // Compute total focus time today
    private var todayFocusMinutes: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = historyStore.history.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let totalSecs = todaySessions.map { $0.duration }.reduce(0, +)
        return Int(totalSecs / 60)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Top Welcome Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(String(
                            localized: "dashboard.welcome.title",
                            defaultValue: "Welcome Back!",
                            comment: "Main welcome heading on dashboard"
                        ))
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                    }
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    Text(String(
                        localized: "dashboard.welcome.subtitle",
                        defaultValue: "Keep your focus game sharp today.",
                        comment: "Welcome subtitle encouraging focus on dashboard"
                    ))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 48) // Clean padding to clear sidebar toggle button area
            
            HStack(spacing: 24) {
                // Left Column: Interactive Flower & Focus Ring
                VStack(spacing: 16) {
                    ZStack {
                        // Focus Ring (track)
                        Circle()
                            .stroke(Color.white.opacity(0.03), lineWidth: 10)
                            .frame(width: 220, height: 220)
                        
                        // Focus Ring (fill)
                        let progress = min(Double(todayFocusMinutes) / Double(dailyFocusGoal), 1.0)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progress))
                            .stroke(
                                Color.brandGradient,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Color.brandGreenStart.opacity(0.35), radius: 10, x: 0, y: 4)
                        
                        // Interactive Blooming Flower View
                        FlowerView(progress: progress)
                            .scaleEffect(frogScale)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
                                    frogScale = 1.15
                                }
                                HapticManager.shared.success()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        frogScale = 1.0
                                    }
                                }
                            }
                    }
                    .frame(height: 230)
                    
                    // Daily Goal
                    Text(String(format: String(
                        localized: "dashboard.stats.daily-goal-progress",
                        defaultValue: "Daily Goal: %dm / %dm",
                        comment: "Daily focus goal progress with current and target minutes"
                    ), todayFocusMinutes, dailyFocusGoal))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(todayFocusMinutes >= dailyFocusGoal ? .green : .secondary)
                }
                .frame(width: 260)
                
                // Right Column: Stats & Quick Task List
                VStack(spacing: 16) {
                    // Quick Stats Grid
                    HStack(spacing: 12) {
                        StatCard(title: String(
                            localized: "dashboard.stats.focused-today.label",
                            defaultValue: "Focused Today",
                            comment: "Label for focused minutes statistic on dashboard"
                        ), value: String(format: String(
                            localized: "dashboard.stats.focused-today.value",
                            defaultValue: "%dm",
                            comment: "Focused minutes value shown in dashboard stats"
                        ), todayFocusMinutes), icon: "flame.fill", color: .orange)
                        StatCard(title: String(
                            localized: "dashboard.stats.completed-tasks.label",
                            defaultValue: "Completed Tasks",
                            comment: "Label for completed tasks statistic on dashboard"
                        ), value: String(format: String(
                            localized: "dashboard.stats.completed-tasks.value",
                            defaultValue: "%d",
                            comment: "Completed tasks count value shown in dashboard stats"
                        ), todoManager.items.filter { $0.isCompleted }.count), icon: "checklist", color: .green)
                    }
                    
                    // Pending Tasks
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(
                            localized: "dashboard.pending-tasks.section-title",
                            defaultValue: "TODAY'S PENDING TASKS",
                            comment: "Section header for today's pending tasks on dashboard"
                        ))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .tracking(1.2)
                        
                        let pendingItems = todoManager.items.filter { !$0.isCompleted }
                        if pendingItems.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green.opacity(0.85))
                                Text(String(
                                    localized: "dashboard.pending-tasks.empty-state",
                                    defaultValue: "All caught up!",
                                    comment: "Empty state message when no pending tasks remain"
                                ))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                VStack(spacing: 6) {
                                    ForEach(pendingItems.prefix(4)) { item in
                                        TaskRowItem(title: item.title)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.025))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    
                    // Start Focus CTA (Premium styling + ambient glow on hover)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeTab = .timer
                        }
                        HapticManager.shared.click()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(String(
                                localized: "dashboard.pending-tasks.start-focus-session",
                                defaultValue: "Start Focus Session",
                                comment: "Button title to start a focus session from dashboard tasks"
                            ))
                                .fontWeight(.bold)
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.18, green: 0.88, blue: 0.48), 
                                        Color(red: 0.05, green: 0.7, blue: 0.35)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                // Ambient hover glow
                                if isPlayHovered {
                                    Color.white.opacity(0.15)
                                }
                            }
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(red: 0.15, green: 0.85, blue: 0.45).opacity(isPlayHovered ? 0.35 : 0.15), radius: isPlayHovered ? 12 : 6, y: 2)
                        .scaleEffect(isPlayHovered ? 1.015 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { isPlayHovered = $0 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Premium StatCard
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.brandSurface.opacity(isHovered ? 0.6 : 0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? color.opacity(0.35) : Color.white.opacity(0.06), lineWidth: isHovered ? 1.0 : 0.5)
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHovered)
    }
}

// MARK: - Interactive Task Row
struct TaskRowItem: View {
    let title: String
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: "circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovered ? 0.05 : 0.02))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.white.opacity(0.08) : Color.clear, lineWidth: 0.5)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
    }
}

// MARK: - DashboardFrogView (fixed tongue connected to mouth)
struct DashboardFrogView: View {
    @ObservedObject var tracker = CursorTracker.shared
    @State private var isBlinking = false
    @State private var isTongueOut = false
    
    private let frogGreen = Color(red: 14/255, green: 127/255, blue: 69/255)
    private let eyebrowColor = Color(red: 10/255, green: 90/255, blue: 45/255)
    private let tonguePink = Color(red: 250/255, green: 103/255, blue: 146/255)
    
    var body: some View {
        ZStack {
            // Head Ellipse
            Ellipse()
                .fill(frogGreen)
                .frame(width: 130, height: 100)
                .position(x: 100, y: 110)
            
            // Left Eyebrow
            Path { path in
                path.move(to: CGPoint(x: 100 - 32, y: 100 - 32))
                path.addQuadCurve(to: CGPoint(x: 100 - 6, y: 100 - 32), control: CGPoint(x: 100 - 19, y: 100 - 39))
            }
            .stroke(eyebrowColor, lineWidth: 4.0)
            
            // Right Eyebrow
            Path { path in
                path.move(to: CGPoint(x: 100 + 6, y: 100 - 32))
                path.addQuadCurve(to: CGPoint(x: 100 + 32, y: 100 - 32), control: CGPoint(x: 100 + 19, y: 100 - 39))
            }
            .stroke(eyebrowColor, lineWidth: 4.0)
            
            // Left Eye
            LargeDashboardEyeView(
                mouseLocation: tracker.mouseLocation,
                eyeCenter: CGPoint(x: 100 - 19.5, y: 100 - 14.5),
                isClosed: isBlinking,
                eyeSize: 38
            )
            .position(x: 100 - 19.5, y: 100 - 14.5)
            
            // Right Eye
            LargeDashboardEyeView(
                mouseLocation: tracker.mouseLocation,
                eyeCenter: CGPoint(x: 100 + 19.5, y: 100 - 14.5),
                isClosed: isBlinking,
                eyeSize: 38
            )
            .position(x: 100 + 19.5, y: 100 - 14.5)
            
            // Smile Mouth (arc)
            Path { path in
                path.move(to: CGPoint(x: 100 - 22.0, y: 100 + 20))
                path.addQuadCurve(
                    to: CGPoint(x: 100 + 22.0, y: 100 + 20),
                    control: CGPoint(x: 100, y: 100 + 33)
                )
            }
            .stroke(Color.black, lineWidth: 4.2)
            
            // Tongue — starts from the bottom center of the mouth arc
            if isTongueOut {
                TonguePath(cx: 100, mouthBottomY: 100 + 28, width: 22, height: 26)
                    .fill(tonguePink)
                    .transition(.scale(scale: 0.1, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(width: 200, height: 200)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                isTongueOut = true
            }
            HapticManager.shared.success()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    isTongueOut = false
                }
            }
        }
        .onAppear {
            scheduleBlink()
        }
    }
    
    private func scheduleBlink() {
        let delay = Double.random(in: 6.0...14.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
                scheduleBlink()
            }
        }
    }
}

// A proper tongue shape: half-capsule that emerges from the mouth, not floating
struct TonguePath: Shape {
    let cx: CGFloat
    let mouthBottomY: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let halfW = width / 2
        let x = cx - halfW
        let y = mouthBottomY
        let r = halfW
        
        p.move(to: CGPoint(x: x, y: y))
        p.addLine(to: CGPoint(x: x, y: y + height - r))
        p.addArc(center: CGPoint(x: cx, y: y + height - r), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: x + width, y: y))
        p.closeSubpath()
        return p
    }
}

// MARK: - Large Dashboard Eye View
struct LargeDashboardEyeView: View {
    let mouseLocation: NSPoint
    let eyeCenter: CGPoint
    let isClosed: Bool
    let eyeSize: CGFloat
    
    var body: some View {
        ZStack {
            if isClosed {
                Path { path in
                    path.move(to: CGPoint(x: 2.0, y: eyeSize * 0.5))
                    path.addQuadCurve(
                        to: CGPoint(x: eyeSize - 2.0, y: eyeSize * 0.5),
                        control: CGPoint(x: eyeSize * 0.5, y: eyeSize * 0.8)
                    )
                }
                .stroke(Color.black, lineWidth: 3.5)
                .frame(width: eyeSize, height: eyeSize)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: eyeSize, height: eyeSize)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2.2))
                
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeSize * 0.48, height: eyeSize * 0.48)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: eyeSize * 0.12, height: eyeSize * 0.12)
                            .offset(x: -eyeSize * 0.08, y: -eyeSize * 0.08)
                    )
                    .offset(pupilOffset())
            }
        }
        .frame(width: eyeSize, height: eyeSize)
    }
    
    private func pupilOffset() -> CGSize {
        guard let window = MainWindow.shared else { return .zero }
        let windowFrame = window.frame
        let sidebarW: CGFloat = 170
        let absoluteCenter = NSPoint(
            x: windowFrame.minX + sidebarW + 24 + eyeCenter.x - 100,
            y: windowFrame.minY + (windowFrame.height - eyeCenter.y - 24)
        )
        
        let dx = mouseLocation.x - absoluteCenter.x
        let dy = mouseLocation.y - absoluteCenter.y
        let distance = sqrt(dx*dx + dy*dy)
        guard distance > 0 else { return .zero }
        
        let maxOffset: CGFloat = eyeSize * 0.22
        let scale = min(distance / 250.0, 1.0) * maxOffset
        return CGSize(width: (dx / distance) * scale, height: -(dy / distance) * scale)
    }
}

// MARK: - FlowerView (bud that blooms when progress reaches 100%)
struct FlowerView: View {
    let progress: Double
    
    var body: some View {
        let petalScale = progress >= 1.0 ? 1.0 : (progress > 0.6 ? (progress - 0.6) / 0.4 : 0.0)
        let petalOpacity = progress >= 1.0 ? 1.0 : (progress > 0.6 ? (progress - 0.6) / 0.4 : 0.0)
        let budOpacity = progress >= 1.0 ? 0.0 : (progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0)
        
        VStack(spacing: 0) {
            ZStack {
                // Blooming Petals (only visible and scaled up when progress approaches 100%)
                ZStack {
                    ForEach(0..<8) { index in
                        let angle = Double(index) * 45.0
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 20, height: 44)
                            .offset(y: -24)
                            .rotationEffect(.degrees(angle))
                    }
                    
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 28, height: 28)
                        .shadow(color: .orange.opacity(0.35), radius: 3)
                }
                .scaleEffect(petalScale)
                .opacity(petalOpacity)
                .rotationEffect(.degrees(progress * 90))
                
                // Closed Flower Bud (visible when progress is less than 1.0)
                ZStack {
                    // Left petal
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .red], startPoint: .top, endPoint: .bottom))
                        .frame(width: 20, height: 42)
                        .rotationEffect(.degrees(-15), anchor: .bottom)
                        .offset(x: -6)
                    
                    // Right petal
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .red], startPoint: .top, endPoint: .bottom))
                        .frame(width: 20, height: 42)
                        .rotationEffect(.degrees(15), anchor: .bottom)
                        .offset(x: 6)
                    
                    // Center petal
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 46)
                }
                .scaleEffect(0.65 + (progress * 0.35)) // grows slightly as progress increases
                .opacity(budOpacity)
            }
            .frame(width: 100, height: 100)
            .offset(y: 10)
            
            // Stem & Leaves
            ZStack(alignment: .bottom) {
                // Stem
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.15, green: 0.75, blue: 0.35))
                    .frame(width: 5, height: 40)
                
                // Left Leaf
                Capsule()
                    .fill(Color(red: 0.15, green: 0.75, blue: 0.35))
                    .frame(width: 20, height: 8)
                    .rotationEffect(.degrees(-25), anchor: .trailing)
                    .offset(x: -12, y: -20)
                
                // Right Leaf
                Capsule()
                    .fill(Color(red: 0.15, green: 0.75, blue: 0.35))
                    .frame(width: 20, height: 8)
                    .rotationEffect(.degrees(25), anchor: .leading)
                    .offset(x: 12, y: -12)
            }
            .frame(height: 40)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: progress)
    }
}
