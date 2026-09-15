# FrogDrop Performance Improvement Plan

This document outlines the identified performance bottlenecks in FrogDrop, their architectural causes, their priority level, and detailed refactoring strategies to eliminate them.

---

## 1. Executive Summary

Our analysis of the FrogDrop codebase has revealed **five major performance bottlenecks** that directly impact UI responsiveness, CPU utilization, and battery drain on macOS. 

The core architectural issue is **blocking the Main Thread (`@MainActor`) with synchronous file I/O, serialization, and heavy image/graphics computation**. Because several central services (`ImageOptimizer`, `PDFToolkit`, `OCRManager`, and `ClipboardManager`) are bound to `@MainActor`, their async methods run synchronously on the main thread unless background context-shifting is explicitly forced. This leads to micro-stutters, beachballing (main-thread hangs), and excessive energy consumption.

---

## 2. Priority & Impact Matrix

| Bottleneck Location | Technical Cause | UI / System Impact | Priority | Recommended Action |
| :--- | :--- | :--- | :--- | :--- |
| **`TodoManager`** | Per-second synchronous JSON serialization & `UserDefaults` writing on `@MainActor` during active timer ticks. | Severe battery drain; high CPU overhead; micro-stutters during active focus/stopwatch sessions. | **P0 (Critical)** | De-couple second-by-second updates from persistent storage. Cache durations in memory; save only on pause/stop/finish or throttled interval. |
| **`ClipboardManager`** | Synchronous file writing (`try data.write(to:)`) on `@MainActor` twice a second inside `checkExpiration` and `checkRetention` checks. | Intermittent beachballs and system-wide copy lag. | **P0 (Critical)** | Move all history disk writes to background tasks. Reduce expiration/retention checks from 0.5s intervals to once-on-launch or on-demand when opening the UI. |
| **`ImageOptimizer`** | Heavy image compression and format conversion (WebP/AVIF) run inside synchronous loops on the `@MainActor`. | Complete UI freezing (application hangs) when processing multiple or large dropped images. | **P1 (High)** | Refactor functions using `Task.detached(priority: .userInitiated)` to move CoreGraphics/ImageIO processing entirely off the main thread. |
| **`PDFToolkit`** | Loading PDFs, rendering image-to-PDF pages, and writing merged PDFs synchronously on `@MainActor`. | Application freezes when merging PDFs or converting image files. | **P1 (High)** | Offload PDF compilation and disk writes to a background task context. |
| **`ShelfGroup` Fallback** | Fallback thumbnail generation via `CGImageSourceCreateThumbnailAtIndex` runs synchronously on the main thread. | Drag-and-drop freezes of several hundred milliseconds when dragging multiple unsupported files. | **P2 (Medium)** | Force the fallback execution onto a background thread using `Task.detached`. |
| **`EXIFExtractor`** | Synchronous EXIF dictionary extraction on `@MainActor` before presenting the inspector panel. | Lag in presenting the EXIF Inspector window when examining large images on slow/network drives. | **P2 (Medium)** | Make the inspector window loading asynchronous, running EXIF extraction in a background thread. |

---

## 3. Detailed Breakdown & Refactoring Strategies

### P0.1: Uncoupling Per-Second Disk Writes in `TodoManager`

#### Current Issue
When a user starts a timer or stopwatch linked to a to-do item, `TimerManager` ticks every second:
```swift
// FrogDrop/Sources/UI/Timer/TimerManager.swift
TodoManager.shared.addDuration(id: todoId, seconds: 1)
```

In `TodoManager.swift`, the duration update immediately triggers a synchronous write to `UserDefaults` via the `items` observer:
```swift
// FrogDrop/Sources/UI/Todo/TodoManager.swift
@Published var items: [TodoItem] = [] {
    didSet { save() } // Triggers on ANY item change
}

func addDuration(id: UUID, seconds: TimeInterval) {
    if let index = items.firstIndex(where: { $0.id == id }) {
        items[index].focusedDuration += seconds
        save() // Writes the ENTIRE list as JSON to UserDefaults every second!
    }
}
```

#### Refactoring Strategy
Rather than persisting to disk every second, we should cache the accumulated duration in an in-memory dictionary. We only flush the accumulated duration to `items` (which writes to `UserDefaults`) when the timer is **paused, completed, stopped, or at a throttled interval (e.g., every 30 seconds)**.

```swift
class TodoManager: ObservableObject {
    // ... Existing properties ...
    
    // In-memory cache for running sessions
    private var pendingDurations: [UUID: TimeInterval] = [:]
    private var saveTimer: Timer?

    func addDuration(id: UUID, seconds: TimeInterval) {
        // Accumulate in memory
        pendingDurations[id, default: 0] += seconds
        
        // Start a lazy flush timer if not already running
        if saveTimer == nil {
            saveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.flushPendingDurations() }
            }
        }
    }
    
    /// Flushes all cached in-memory durations to persistent storage
    func flushPendingDurations() {
        saveTimer?.invalidate()
        saveTimer = nil
        
        guard !pendingDurations.isEmpty else { return }
        
        var modified = false
        for (id, elapsed) in pendingDurations {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].focusedDuration += elapsed
                modified = true
            }
        }
        pendingDurations.removeAll()
        
        if modified {
            save() // Write once instead of 30 times!
        }
    }
}
```

---

### P0.2: Throttling & Offloading Clipboard History Operations

#### Current Issue
In `ClipboardManager.swift`, a 0.5s timer polls the pasteboard on the main thread and calls:
```swift
private func checkPasteboard() {
    checkExpiration() // Filters items & calls saveHistory() synchronously
    checkRetention()  // Filters items & calls saveHistory() synchronously
    guard pasteboard.changeCount != lastChangeCount else { return }
    // ...
}
```

If anything expires, it calls `saveHistory()`, which blocks the main thread with synchronous I/O:
```swift
private func saveHistory() {
    do {
        let data = try JSONEncoder().encode(items)
        try data.write(to: storageURL) // SYNCHRONOUS DISK WRITE ON MAIN ACTOR TWICE A SECOND!
    } catch { ... }
}
```

#### Refactoring Strategy
1. **Reduce Check Frequency**: Run `checkExpiration()` and `checkRetention()` only on app startup, when the Clipboard tab view actually appears on screen (via `.onAppear`), or on a much larger interval (e.g., every 5 minutes). Do NOT run them twice a second.
2. **Asynchronous Disk Writes**: Offload `saveHistory` JSON encoding and disk writing to a background task.

```swift
// Move history serialization off the main thread
private func saveHistory() {
    let itemsToSave = self.items // Value-copy (Thread-safe Struct array)
    let url = self.storageURL
    
    Task.detached(priority: .background) {
        do {
            let data = try JSONEncoder().encode(itemsToSave)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save clipboard history on background thread: \(error)")
        }
    }
}
```

---

### P1.1: Background Processing in `@MainActor` Utility Classes (`ImageOptimizer` & `PDFToolkit`)

#### Current Issue
Both `ImageOptimizer` and `PDFToolkit` are marked `@MainActor`. Although their methods are `async`, there are no suspension points (`await` calls that yield execution to background threads) inside their processing loops. 

For example, in `ImageOptimizer.swift`:
```swift
@MainActor
class ImageOptimizer {
    func convertToWebP(urls: [URL]) async -> [URL] {
        for url in urls {
            // Loading, optimizing, formatting, and writing to disk
            // are all executed synchronously on the main thread!
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil), ...
            CGImageDestinationFinalize(destination) // Block!
        }
        return results
    }
}
```

#### Refactoring Strategy
We must remove CPU-intensive processing from `@MainActor`. Since we are using Swift Concurrency, we should perform the calculations within `Task.detached(priority: .userInitiated)` to explicitly shift work to background threads, and only hop back to the `@MainActor` for UI-related interactions (such as updating state progress, notifications, and opening Finder/Downloads).

```swift
func convertToWebP(urls: [URL]) async -> [URL] {
    let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    
    // Explicitly run CPU-bound work on background thread pool
    let results = await Task.detached(priority: .userInitiated) { () -> [URL] in
        var outputURLs: [URL] = []
        for url in urls {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                continue
            }
            let baseName = url.deletingPathExtension().lastPathComponent
            let avifURL = downloadsDir.appendingPathComponent("\(baseName).avif")
            
            if let destination = CGImageDestinationCreateWithURL(avifURL as CFURL, "public.avif" as CFString, 1, nil) {
                let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    outputURLs.append(avifURL)
                    continue
                }
            }
            // Fallback JPEG ...
        }
        return outputURLs
    }.value
    
    // Resume on MainActor for UI/HUD/Notification actions
    if !results.isEmpty {
        HapticManager.shared.success()
        notifyUser(title: "Converted to Web Format", body: "\(results.count) image(s) saved to Downloads.")
        NSWorkspace.shared.activateFileViewerSelecting(results)
    }
    return results
}
```

*This same `Task.detached` refactoring strategy will be applied to `ImageOptimizer.compressImages`, `ImageOptimizer.stripMetadata`, `PDFToolkit.mergePDFs`, and `OCRManager.extractText` to entirely prevent main-thread hangs.*

---

### P2.1: Non-Blocking Thumbnail Generation in `ShelfGroup`

#### Current Issue
In `ShelfGroup.swift`, the fallback thumbnail generator runs synchronously:
```swift
static func generateThumb(for url: URL) async -> NSImage? {
    // QLThumbnailGenerator is async ...
    do {
         let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
         return representation.nsImage
    } catch {
         // FALLBACK: Runs synchronously on whatever thread called it!
         guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, ...) else { return nil }
         return NSImage(cgImage: cg, size: ...)
    }
}
```
Since `DropzoneManager` calls this within an unstructured `Task { ... }` block that inherits the `@MainActor` context, the synchronous fallback image rendering is executed directly on the main thread, causing lags when dragging multiple unsupported formats.

#### Refactoring Strategy
Ensure that the entire `generateThumb` calculation is isolated from the main actor context.

```swift
static func generateThumb(for url: URL) async -> NSImage? {
    // Force fallback onto cooperative thread pool
    return await Task.detached(priority: .userInitiated) { () -> NSImage? in
        let size = CGSize(width: 80, height: 80)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2.0, representationTypes: .thumbnail)
        
        do {
            // Intercept async call inside background context
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return representation.nsImage
        } catch {
            let exts = ["jpg","jpeg","png","gif","heic","heif","tiff","bmp","webp","pdf"]
            guard exts.contains(url.pathExtension.lowercased()),
                  let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 80] as CFDictionary)
            else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: 40, height: 40))
        }
    }.value
}
```

---

## 4. Verification and Performance Testing Plan

To guarantee that these improvements successfully eliminate lags and do not introduce regressions, the following verification pipeline is established:

1. **Static Analysis & Compiler Checks**:
   - Run `XcodeRefreshCodeIssuesInFile` to ensure complete type safety, accurate concurrency checks, and `@Sendable` compliance across all refactored background tasks.
2. **Main Thread Diagnostics**:
   - Build and run FrogDrop using Xcode's **Thread Performance Checker** and **Instruments (Time Profiler / Hang Tracer)**. 
   - Measure main-thread utilization during heavy file drag operations (such as dropping 10 large JPEG files for WebP conversion and EXIF stripping) and active timer countdowns to confirm main-thread occupancy remains **below 5%**.
3. **Automated Unit Verification**:
   - Write unit tests in `FrogDropTests` to mock high-frequency time ticking and confirm that `TodoManager` writes to persistent storage only once at the conclusion of active focus sessions, or at the throttled threshold.
