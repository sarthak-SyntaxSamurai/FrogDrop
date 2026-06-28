import AppKit
import SwiftUI

class ToastModel: ObservableObject {
    @Published var text: String = ""
    @Published var appName: String = ""
    @Published var isTemporary: Bool = false
    @Published var itemId: UUID? = nil
}

struct ClipboardToastView: View {
    @ObservedObject var model: ToastModel
    var onStayClicked: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
                .padding(4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Circle())
            
            Text("Temporary Item")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer().frame(width: 4)
            
            Button(action: {
                onStayClicked()
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
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
            contentRect: NSRect(x: 0, y: 0, width: 170, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false // Allow clicking the Stay button
        
        let view = ClipboardToastView(model: model) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                // Find and make the active temporary item permanent
                if let firstTemp = ClipboardManager.shared.items.first(where: { $0.isTemporary }) {
                    ClipboardManager.shared.makePermanent(firstTemp)
                    HapticManager.shared.success()
                }
            }
            self.hide()
        }
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)
    }
    
    func show(statusItemFrame: NSRect, text: String, appName: String, isTemporary: Bool) {
        // ONLY show the notification panel for temporary copies
        guard isTemporary else { return }
        
        let width: CGFloat = 170
        let height: CGFloat = 32
        
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
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
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
