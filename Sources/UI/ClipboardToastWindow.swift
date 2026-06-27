import AppKit
import SwiftUI

class ToastModel: ObservableObject {
    @Published var text: String = ""
    @Published var appName: String = ""
    @Published var isTemporary: Bool = false
}

struct ClipboardToastView: View {
    @ObservedObject var model: ToastModel
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: model.isTemporary ? "clock.arrow.2.circlepath" : "doc.on.clipboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(model.isTemporary ? .orange : Color(red: 0.15, green: 0.85, blue: 0.45))
                .padding(6)
                .background((model.isTemporary ? Color.orange : Color(red: 0.15, green: 0.85, blue: 0.45)).opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(model.appName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if model.isTemporary {
                        Text("Temp")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(2)
                    }
                }
                
                let displayPreviewText = model.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "\t", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                Text(displayPreviewText.prefix(28) + (displayPreviewText.count > 28 ? "..." : ""))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

class ClipboardToastPanelWindow: NSWindow {
    static let shared = ClipboardToastPanelWindow()
    
    private let model = ToastModel()
    private var hideTimer: Timer?
    private var startY: CGFloat = 0
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 42),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = true
        
        let view = ClipboardToastView(model: model)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)
    }
    
    func show(statusItemFrame: NSRect, text: String, appName: String, isTemporary: Bool) {
        let width: CGFloat = 220
        let height: CGFloat = 42
        
        self.model.text = text
        self.model.appName = appName
        self.model.isTemporary = isTemporary
        
        let startRect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY + 5,
            width: width,
            height: height
        )
        
        let endRect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 4,
            width: width,
            height: height
        )
        
        self.startY = startRect.minY
        self.setFrame(startRect, display: true)
        self.alphaValue = 0.0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(endRect, display: true)
            self.animator().alphaValue = 1.0
        }
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    private func hide() {
        let width = self.frame.width
        let height = self.frame.height
        let targetRect = NSRect(
            x: self.frame.minX,
            y: self.startY,
            width: width,
            height: height
        )
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(targetRect, display: true)
            self.animator().alphaValue = 0.0
        }) {
            self.orderOut(nil)
        }
    }
}
