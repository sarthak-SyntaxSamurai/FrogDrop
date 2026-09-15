import SwiftUI

// MARK: - TasksTabView (Dedicated First-Class Tab in FrogHub & FrogStudio)
struct TasksTabView: View {
    @ObservedObject var todoManager = TodoManager.shared
    @State private var newTaskText: String = ""
    @State private var filter: TaskFilter = .all
    @State private var isInputHovered: Bool = false
    
    var onStartFocus: ((String, UUID) -> Void)?
    
    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case done = "Done"
        
        var id: String { rawValue }
    }
    
    private var filteredItems: [TodoItem] {
        switch filter {
        case .all:
            return todoManager.items
        case .active:
            return todoManager.items.filter { !$0.isCompleted }
        case .done:
            return todoManager.items.filter { $0.isCompleted }
        }
    }
    
    private var pendingCount: Int {
        todoManager.items.filter { !$0.isCompleted }.count
    }
    
    private var completedCount: Int {
        todoManager.items.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header & Counter
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("Tasks")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("\(pendingCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.brandGreenEnd)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.brandGreenStart.opacity(0.15)))
                        .overlay(Capsule().stroke(Color.brandGreenEnd.opacity(0.25), lineWidth: 0.5))
                }
                
                Spacer()
                
                // Filter Segmented Control
                HStack(spacing: 2) {
                    ForEach(TaskFilter.allCases) { item in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                filter = item
                            }
                            HapticManager.shared.tick()
                        }) {
                            Text(item.rawValue)
                                .font(.system(size: 10, weight: filter == item ? .bold : .medium, design: .rounded))
                                .foregroundColor(filter == item ? .primary : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(filter == item ? Color.white.opacity(0.12) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.04))
                .cornerRadius(7)
                
                // Clear Done Button
                if completedCount > 0 {
                    Button(action: {
                        withAnimation {
                            todoManager.items.removeAll { $0.isCompleted }
                        }
                        HapticManager.shared.click()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear Completed Tasks")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            
            // Task Input Field
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundColor(Color.brandGreenEnd)
                    .font(.system(size: 11, weight: .bold))
                
                TextField("Add a new task & press Return...", text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .onSubmit {
                        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        todoManager.add(title: trimmed)
                        newTaskText = ""
                        HapticManager.shared.success()
                    }
                
                if !newTaskText.isEmpty {
                    Button(action: {
                        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            todoManager.add(title: trimmed)
                            newTaskText = ""
                            HapticManager.shared.success()
                        }
                    }) {
                        Text("Add")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.brandGreenEnd)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.brandGreenStart.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(isInputHovered ? 0.08 : 0.04))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isInputHovered ? Color.brandGreenEnd.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .onHover { hovering in
                isInputHovered = hovering
            }
            
            // Task Items Scroll List
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: filter == .done ? "checkmark.seal" : "checklist")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text(emptyMessage)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 5) {
                        ForEach(filteredItems) { item in
                            TaskRowCard(
                                item: item,
                                onStartFocus: {
                                    onStartFocus?(item.title, item.id)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyMessage: String {
        switch filter {
        case .all:
            return "No tasks yet. Type above to add what you're working on today."
        case .active:
            return "All caught up! No active tasks pending."
        case .done:
            return "No completed tasks yet. Finish a task to see it here."
        }
    }
}

// MARK: - TaskRowCard
struct TaskRowCard: View {
    let item: TodoItem
    @ObservedObject var todoManager = TodoManager.shared
    var onStartFocus: (() -> Void)?
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Checkmark button
            Button(action: {
                todoManager.toggle(id: item.id)
                HapticManager.shared.click()
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? Color.brandGreenEnd : .secondary.opacity(0.6))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            
            // Title
            Text(item.title)
                .font(.system(.subheadline, design: .rounded))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary.opacity(0.65) : .primary)
                .lineLimit(2)
            
            // Duration focused badge
            if item.focusedDuration > 0 {
                Text(formatDuration(item.focusedDuration))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.brandGreenEnd)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.brandGreenStart.opacity(0.12)))
            }
            
            Spacer()
            
            // Hover action buttons
            if isHovering {
                HStack(spacing: 6) {
                    if !item.isCompleted {
                        // Start Focus Button
                        Button(action: {
                            onStartFocus?()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8))
                                Text("Focus")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.brandGreenStart))
                        }
                        .buttonStyle(.plain)
                        .help("Focus on this task with Pomodoro timer")
                    }
                    
                    // Delete Button
                    Button(action: {
                        withAnimation {
                            todoManager.delete(id: item.id)
                        }
                        HapticManager.shared.tick()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovering ? 0.06 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering ? Color.white.opacity(0.1) : Color.white.opacity(0.04), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hrs = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
