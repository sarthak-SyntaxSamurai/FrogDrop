import SwiftUI
import AppKit

// Clear Button with Hover State
struct ClearButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundColor(.red.opacity(isHovered ? 1.0 : 0.7))
                .padding(7)
                .background(Color.red.opacity(isHovered ? 0.15 : 0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(isHovered ? 0.25 : 0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// ==================== CLIPBOARD TAB ====================
struct ClipboardTabView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var searchQuery: String
    @State private var isSearchHovered = false
    
    var filteredItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]
        if searchQuery.isEmpty {
            baseItems = clipboardManager.items
        } else {
            baseItems = clipboardManager.items.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
        }
        return baseItems.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Search & Clear Header
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search history...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(.subheadline, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(isSearchHovered ? 0.08 : 0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .onHover { hovering in
                    isSearchHovered = hovering
                }
                
                // Clear all
                ClearButton {
                    clipboardManager.clearAll()
                    HapticManager.shared.success()
                }
                .help("Clear History")
            }
            .padding(.horizontal, 14)
            
            // Clipboard List
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.bottom, 6)
                    Text("Clipboard is empty")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            ClipboardRow(item: item, searchQuery: searchQuery) {
                                clipboardManager.copyToPasteboard(item)
                            } onDelete: {
                                clipboardManager.deleteItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

fileprivate extension String {
    func ranges(of searchString: String, options: CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var start = startIndex
        while start < endIndex,
              let range = range(of: searchString, options: options, range: start..<endIndex) {
            result.append(range)
            start = range.upperBound
        }
        return result
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let searchQuery: String
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var hoverWorkItem: DispatchWorkItem? = nil
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var isTruncated: Bool {
        item.text.count > 38 || item.text.contains("\n") || item.text.contains("\r")
    }
    
    private var displayPreviewText: String {
        item.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var remainingSeconds: Int {
        guard let expiry = item.expiresAt else { return 0 }
        return max(0, Int(expiry.timeIntervalSince(Date())))
    }
    
    private func highlightedText(_ fullText: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(fullText)
        }
        
        let ranges = fullText.ranges(of: query, options: .caseInsensitive)
        guard !ranges.isEmpty else {
            return Text(fullText)
        }
        
        var result = Text("")
        var currentIndex = fullText.startIndex
        
        for range in ranges {
            let preMatch = String(fullText[currentIndex..<range.lowerBound])
            result = result + Text(preMatch)
            
            let match = String(fullText[range])
            result = result + Text(match).bold().foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
            
            currentIndex = range.upperBound
        }
        
        let postMatch = String(fullText[currentIndex...])
        result = result + Text(postMatch)
        
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(.trailing, 2)
                    }
                    
                    if isEditing {
                        TextField("", text: $editText, onCommit: {
                            ClipboardManager.shared.updateText(item, newText: editText)
                            isEditing = false
                        })
                        .focused($isTextFieldFocused)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .textFieldStyle(.plain)
                        .padding(2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                        .onAppear {
                            editText = item.text
                            isTextFieldFocused = true
                        }
                    } else {
                        highlightedText(displayPreviewText, query: searchQuery)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                if item.isTemporary {
                    Button(action: {
                        ClipboardManager.shared.makePermanent(item)
                        HapticManager.shared.success()
                    }) {
                        Text("Stay")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 0.15, green: 0.85, blue: 0.45))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                if isHovering {
                    HStack(spacing: 4) {
                        if !pathsAndURLs.isEmpty {
                            Button(action: {
                                openItemLinksAndPaths()
                            }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                    .padding(5)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .help("Open Link or Path")
                        }
                        
                        Button(action: {
                            editText = item.text
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .padding(5)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Edit Item")
                        
                        Button(action: {
                            ClipboardManager.shared.togglePin(item)
                            HapticManager.shared.click()
                        }) {
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(item.isPinned ? .orange : .green)
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin Item" : "Pin Item")
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .padding(5)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Item")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: isHovering ?
                                [Color.white.opacity(0.08), Color.white.opacity(0.02)] :
                                [Color.white.opacity(0.02), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovering ?
                            LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.white.opacity(0.05), Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: isHovering ? Color.black.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
            .scaleEffect(isHovering ? 1.015 : 1.0)
            .offset(y: isHovering ? -1 : 0)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
                
                hoverWorkItem?.cancel()
                
                if hovering {
                    guard isTruncated else { return }
                    
                    let workItem = DispatchWorkItem {
                        if isHovering {
                            let frame = geometry.frame(in: .named("PopupWindowSpace"))
                            ClipboardPreviewManager.shared.showPreview(for: item, atRowFrame: frame)
                        }
                    }
                    hoverWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                } else {
                    hoverWorkItem = nil
                    ClipboardPreviewManager.shared.hidePreview()
                }
            }
            .onTapGesture {
                guard !isEditing else { return }
                onCopy()
                hoverWorkItem?.cancel()
                hoverWorkItem = nil
                ClipboardPreviewManager.shared.hidePreview()
                if let delegate = NSApp.delegate as? AppDelegate { delegate.closeAllPanels() }
            }
        }
        .frame(height: 34)
    }
    
    private var pathsAndURLs: [URL] {
        var urls: [URL] = []
        let lines = item.text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                if let url = URL(string: trimmed) {
                    urls.append(url)
                }
            } else if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
                let expanded = (trimmed as NSString).expandingTildeInPath
                let fileURL = URL(fileURLWithPath: expanded)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    urls.append(fileURL)
                }
            }
        }
        return urls
    }
    
    private func openItemLinksAndPaths() {
        let targets = pathsAndURLs
        guard !targets.isEmpty else { return }
        
        HapticManager.shared.success()
        for url in targets {
            NSWorkspace.shared.open(url)
        }
        
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.closeAllPanels()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
