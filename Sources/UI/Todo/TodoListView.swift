import SwiftUI

struct TodoListView: View {
    @ObservedObject var todoManager = TodoManager.shared
    @State private var newTodoText = ""
    @State private var isInputHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("To-Do List")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Task input field
            HStack {
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11, weight: .bold))
                TextField("Add task...", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .onSubmit {
                        todoManager.add(title: newTodoText)
                        newTodoText = ""
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(isInputHovered ? 0.08 : 0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInputHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .onHover { hovering in
                isInputHovered = hovering
            }
            
            // To-do ScrollView
            if todoManager.items.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No tasks yet")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(height: 110)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(todoManager.items) { item in
                            TodoRow(item: item)
                        }
                    }
                }
                .frame(height: 110)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var todoManager = TodoManager.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                todoManager.toggle(id: item.id)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .font(.system(.subheadline, design: .rounded))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary.opacity(0.7) : .primary)
                .lineLimit(1)
            
            let durStr = formatFocusedDuration(item.focusedDuration)
            if !durStr.isEmpty {
                Text(durStr)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 8) {
                    // Play Timer Option
                    Button(action: {
                        TimerManager.shared.setupSeconds = 25 * 60 // 25m default
                        TimerManager.shared.setupTaskName = item.title
                        TimerManager.shared.setupTodoId = item.id
                        TimerManager.shared.isShowingSetup = true
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(5)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Start Focus Timer")
                    
                    // Stopwatch Option
                    Button(action: {
                        TimerManager.shared.startStopwatch(name: item.title, todoId: item.id)
                    }) {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                            .padding(5)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Start Stopwatch")
                    
                    // Delete Option
                    Button(action: {
                        todoManager.delete(id: item.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                            .padding(5)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Task")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovering ? 0.05 : 0.01))
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatFocusedDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "" }
        let hrs = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        if hrs > 0 {
            if mins > 0 {
                return "\(hrs)h \(mins)m"
            }
            return "\(hrs)h"
        } else {
            return "\(mins)m"
        }
    }
}
