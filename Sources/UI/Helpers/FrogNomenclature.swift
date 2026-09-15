import Foundation
import AppKit
import SwiftUI

// MARK: - FrogDrop Spatial UI Architecture & Standard Nomenclature
///
/// FrogDrop organizes its UI into a unified 5-Layer Spatial Interface Model:
///
/// 1. **FrogHub** (`PopupView` / `PopupPanelWindow`):
///    The main menu bar popover and detachable panel. Provides rapid triage for
///    Focus, Clips, Shelf, and Tasks.
///
/// 2. **DropDock** (`DropzonePanelWindow` / `DropzonePanelView`):
///    The top-edge slide-in action tray. Summons when files are dragged toward the
///    menu bar/notch for instant transforms (OCR, WebP, EXIF, PDF merge).
///
/// 3. **FrogShelf** (`FloatingShelfWindow` / `FloatingShelfManager`):
///    The cursor-anchored quick shelf spawned by shaking the mouse during a drag.
///    Serves as a temporary holding zone across Desktops and fullscreen apps.
///
/// 4. **FocusIsland** (`FloatingFocusPillPanel` / `FloatingFocusPillManager`):
///    The compact, always-on-top Picture-in-Picture floating focus HUD.
///
/// 5. **TongueSnap** (`TongueOverlayWindow` / `TongueOverlayView`):
///    The interactive drag-down radial gesture launcher from the menu bar mascot.
///
/// 6. **ClipToast** (`ClipboardToastPanelWindow` / `ClipboardToastView`):
///    Transient copy-feedback HUD capsule.
///
/// 7. **ClipLens** (`ClipboardPreviewWindow` / `ClipboardPreviewView`):
///    Floating frosted glass inspector for multi-line clipboard previews.
///
/// 8. **FrogStudio** (`MainWindow` / `DashboardView` / `MainSidebarView`):
///    The full desktop workstation window for analytics, vault, and bulk tools.
///
/// 9. **PrivacyLens** (`EXIFInspectorView`):
///    Floating sheet for inspecting and stripping photo EXIF & GPS metadata.

// MARK: - Standard Nomenclature Typealiases

// FrogHub (Menu Bar Popover & Detachable Panel)
typealias FrogHubView = PopupView
typealias FrogHubPanelWindow = PopupPanelWindow

// DropDock (Top-Edge Slide-in Action Drawer)
typealias DropDockPanelWindow = DropzonePanelWindow
typealias DropDockPanelView = DropzonePanelView

// FrogShelf (Cursor-Summoned Quick Shelf)
typealias FrogShelfWindow = FloatingShelfWindow
typealias FrogShelfManager = FloatingShelfManager

// FocusIsland (Dynamic Island Floating Focus Pill)
typealias FocusIslandPanel = FloatingFocusPillPanel
typealias FocusIslandManager = FloatingFocusPillManager
typealias FocusIslandView = FloatingFocusPillView

// TongueSnap (Elastic Radial Gesture Launcher)
typealias TongueSnapOverlayWindow = TongueOverlayWindow
typealias TongueSnapOverlayView = TongueOverlayView

// ClipToast & ClipLens
typealias ClipToastPanelWindow = ClipboardToastPanelWindow
typealias ClipLensWindow = ClipboardPreviewWindow

// FrogStudio (Desktop Dashboard Window)
typealias FrogStudioWindow = MainWindow

// MARK: - Spatial UI Configuration & Screen Boundaries
struct FrogSpatialConfig {
    /// Standard size for the FrogHub menu bar popover / panel
    static let frogHubSize = CGSize(width: 360, height: 490)
    
    /// Default size for the Focus Island HUD
    static let focusIslandSize = CGSize(width: 220, height: 42)
    
    /// Default size for the full FrogStudio desktop window
    static let frogStudioMinSize = CGSize(width: 740, height: 500)
    static let frogStudioDefaultSize = CGSize(width: 840, height: 560)
    
    /// DropDock expanded dimensions
    static let dropDockWidth: CGFloat = 280
    static let dropDockMaxHeight: CGFloat = 690
}
