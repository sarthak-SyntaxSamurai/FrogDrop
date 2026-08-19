import SwiftUI

struct DropzoneTabView: View {
    @ObservedObject var dropzoneManager = DropzoneManager.shared
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text(String(
                    localized: "dropzone.tab.header.title",
                    defaultValue: "FROG DROP",
                    bundle: .main,
                    comment: "Title text shown at top of dropzone tab"
                ))
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                    .tracking(1.2)
                Spacer()
            }
            .frame(height: 16)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 10)
            
            // Compact drop zone — always visible at top
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isTargeted ? Color.green : Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 0.5, dash: [4, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTargeted ? Color.green.opacity(0.06) : Color.clear)
                    )
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 12))
                        .foregroundColor(isTargeted ? .green : .secondary)
                    Text(isTargeted ? String(
                        localized: "dropzone.tab.drop-target.title",
                        defaultValue: "Drop files here",
                        bundle: .main,
                        comment: "Instruction shown while dragging files over dropzone"
                    ) : String(
                        localized: "dropzone.tab.drop-target.subtitle",
                        defaultValue: "Drag files here to store",
                        bundle: .main,
                        comment: "Instruction shown when not dragging files over dropzone"
                    ))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isTargeted ? .green : .secondary)
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 0)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                var urls: [URL] = []
                let group = DispatchGroup()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url { urls.append(url) }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    if !urls.isEmpty { dropzoneManager.shelfFiles(urls) }
                }
                return true
            }
            
            // Scrollable grid — always shows shelf + folders + ACTIONS
            ScrollView(.vertical, showsIndicators: true) {
                DropzoneGrid(isDraggingMode: false)
                    .padding(.bottom, 20)
            }
        }
    }
}
