# Sidebar Overlap Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the overlap between the floating sidebar toggle button and the "FrogDrop" logo in the sidebar layout.

**Architecture:** Apply `.edgesIgnoringSafeArea(.all)` to the outer `ZStack` in `MainSidebarView` to align the coordinate systems of both the sidebar and the toggle button to the top-left of the window (Y = 0). This ensures the toggle button sits at Y = 12 and the logo sits at Y = 56 without overlap.

**Tech Stack:** Swift, SwiftUI, AppKit.

## Global Constraints
- Target platform: macOS 14.0+
- Keep code changes minimal and focused.

---

### Task 1: Align Safe Area Behavior in MainSidebarView

**Files:**
- Modify: [MainSidebarView.swift](file:///Users/sarthakanand/Projects/new%20app/FrogDrop/Sources/UI/MainSidebarView.swift)

**Interfaces:**
- Consumes: None
- Produces: None

- [ ] **Step 1: Modify MainSidebarView.swift to apply edgesIgnoringSafeArea to the outer ZStack**

Modify [MainSidebarView.swift](file:///Users/sarthakanand/Projects/new%20app/FrogDrop/Sources/UI/MainSidebarView.swift#L32-L36):
```swift
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main App Layout
            HStack(spacing: 0) {
```
to apply `.edgesIgnoringSafeArea(.all)` to the outer `ZStack`:
```swift
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main App Layout
            HStack(spacing: 0) {
                // Collapsible Sidebar
                if isSidebarVisible {
```
and at the end of the `ZStack` [MainSidebarView.swift#L135-L137]:
```swift
            .padding(.top, 12)
        }
    }
```
add `.edgesIgnoringSafeArea(.all)`:
```swift
            .padding(.top, 12)
        }
        .edgesIgnoringSafeArea(.all)
    }
```

- [ ] **Step 2: Compile the app**

Run: `swift build`
Expected output: Build complete!

- [ ] **Step 3: Run the app to verify the fix**

Run: `swift run`
Expected: The app runs. Visually verify that the toggle button sits at Y = 12 (to the right of the traffic lights) and the logo starts below it at Y = 56, with no overlap.

- [ ] **Step 4: Commit the changes**

Run:
```bash
git add Sources/UI/MainSidebarView.swift
git commit -m "fix: align safe area handling to resolve sidebar button overlap"
```
