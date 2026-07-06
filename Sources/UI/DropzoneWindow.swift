import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import ServiceManagement

enum TaskProgressState: Equatable {
    case idle
    case running(String)
    case success(String)
    case failure(String)
}

// Struct representing a customizable Dropzone item
struct DropzoneItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let type: String // "folder" or "action"
    let name: String
    var path: String? // for folders
    var actionType: String? // for actions
}

struct ShelfGroup: Identifiable {
    let id = UUID()
    var files: [URL]
    var thumbnails: [URL: NSImage] = [:]
    
    static func generateThumb(for url: URL) -> NSImage? {
        let exts = ["jpg","jpeg","png","gif","heic","heif","tiff","bmp","webp","pdf"]
        guard exts.contains(url.pathExtension.lowercased()),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 80] as CFDictionary)
        else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: 40, height: 40))
    }
}

@MainActor class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    @Published var shelvedGroups: [ShelfGroup] = []
    @Published var currentlyDraggingGroup: ShelfGroup? = nil
    var shelvedFiles: [URL] { shelvedGroups.flatMap { $0.files } } // compat shim
    @Published var hoveredActionKey: String? = nil
    @Published var customFolders: [DropzoneItem] = []
    @Published var enabledActions: [String] = ["airdrop", "email", "imgur", "shortenURL", "zip", "resizeImage", "convertImage", "copyPath"]
    @Published var lastDropTime: Date? = nil
    @Published var registeredFrames: [String: NSRect] = [:]
    @Published var actionProgress: [String: TaskProgressState] = [:]
    @Published var isShowingCombinePopover = false
    @Published var selectedGroupIDs: Set<UUID> = []
    
    private let foldersKey = "frogdrop.customFolders"
    private let actionsKey = "frogdrop.enabledActions"
    // All possible actions — always merged in
    private let allActions = ["airdrop", "email", "imgur", "shortenURL", "zip", "resizeImage", "convertImage", "copyPath"]
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([DropzoneItem].self, from: data) {
            self.customFolders = decoded
        } else {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            self.customFolders = [
                DropzoneItem(id: UUID(), type: "folder", name: "Downloads", path: downloadsURL.path)
            ]
        }
        
        if var actions = UserDefaults.standard.stringArray(forKey: actionsKey) {
            // Merge any new actions not yet saved
            for a in allActions { if !actions.contains(a) { actions.append(a) } }
            self.enabledActions = actions
        } else {
            self.enabledActions = allActions
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(customFolders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
        UserDefaults.standard.set(enabledActions, forKey: actionsKey)
    }
    
    func addFolder(name: String, path: String) {
        let newItem = DropzoneItem(id: UUID(), type: "folder", name: name, path: path)
        customFolders.append(newItem)
        saveSettings()
    }
    
    func removeFolder(id: UUID) {
        customFolders.removeAll(where: { $0.id == id })
        saveSettings()
    }
    
    func toggleAction(_ actionType: String, enabled: Bool) {
        if enabled {
            if !enabledActions.contains(actionType) {
                enabledActions.append(actionType)
            }
        } else {
            enabledActions.removeAll(where: { $0 == actionType })
        }
        saveSettings()
    }
    
    func registerFrame(_ rect: NSRect, for key: String) {
        registeredFrames[key] = rect
    }
    
    func shelfFiles(_ urls: [URL]) {
        // Files dropped together form one group
        var group = ShelfGroup(files: urls)
        for url in urls {
            if let thumb = ShelfGroup.generateThumb(for: url) {
                group.thumbnails[url] = thumb
            }
        }
        shelvedGroups.append(group)
        lastDropTime = Date()
        HapticManager.shared.success()
    }
    
    func clearShelf() {
        shelvedGroups.removeAll()
        lastDropTime = nil
    }
    
    func combineFiles(_ urls: [URL], intoGroupAt index: Int) {
        guard index >= 0 && index < shelvedGroups.count else { return }
        var group = shelvedGroups[index]
        let existingPaths = Set(group.files.map { $0.path })
        let newFiles = urls.filter { !existingPaths.contains($0.path) }
        guard !newFiles.isEmpty else { return }
        group.files.append(contentsOf: newFiles)
        for url in newFiles {
            if let thumb = ShelfGroup.generateThumb(for: url) {
                group.thumbnails[url] = thumb
            }
        }
        shelvedGroups[index] = group
        HapticManager.shared.success()
    }
    
    func deleteShelfGroup(at index: Int) {
        if index >= 0 && index < shelvedGroups.count {
            shelvedGroups.remove(at: index)
        }
        if shelvedGroups.isEmpty { lastDropTime = nil }
    }
    
    func deleteShelfGroup(where predicate: (ShelfGroup) -> Bool) {
        if let index = shelvedGroups.firstIndex(where: predicate) {
            shelvedGroups.remove(at: index)
        }
        if shelvedGroups.isEmpty { lastDropTime = nil }
    }
    
    func combineAllGroups() {
        guard shelvedGroups.count > 1 else { return }
        let allFiles = shelvedGroups.flatMap { $0.files }
        // Remove duplicates by path
        var seenPaths = Set<String>()
        let uniqueFiles = allFiles.filter { seenPaths.insert($0.path).inserted }
        
        var combinedGroup = ShelfGroup(files: uniqueFiles)
        for group in shelvedGroups {
            for (url, thumb) in group.thumbnails {
                combinedGroup.thumbnails[url] = thumb
            }
        }
        for url in uniqueFiles {
            if combinedGroup.thumbnails[url] == nil, let thumb = ShelfGroup.generateThumb(for: url) {
                combinedGroup.thumbnails[url] = thumb
            }
        }
        
        shelvedGroups = [combinedGroup]
        HapticManager.shared.success()
    }
    
    func combineGroups(withIDs ids: Set<UUID>) {
        guard ids.count > 1 else { return }
        
        var filesToCombine: [URL] = []
        var remainingGroups: [ShelfGroup] = []
        
        var combinedGroup = ShelfGroup(files: [])
        
        for group in shelvedGroups {
            if ids.contains(group.id) {
                filesToCombine.append(contentsOf: group.files)
                for (url, thumb) in group.thumbnails {
                    combinedGroup.thumbnails[url] = thumb
                }
            } else {
                remainingGroups.append(group)
            }
        }
        
        var seenPaths = Set<String>()
        let uniqueFiles = filesToCombine.filter { seenPaths.insert($0.path).inserted }
        combinedGroup.files = uniqueFiles
        
        for url in uniqueFiles {
            if combinedGroup.thumbnails[url] == nil, let thumb = ShelfGroup.generateThumb(for: url) {
                combinedGroup.thumbnails[url] = thumb
            }
        }
        
        remainingGroups.append(combinedGroup)
        self.shelvedGroups = remainingGroups
        HapticManager.shared.success()
    }
    
    func setProgress(_ state: TaskProgressState, for actionKey: String) {
        actionProgress[actionKey] = state
        if case .success = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.actionProgress[actionKey] = .idle
            }
        } else if case .failure = state {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.actionProgress[actionKey] = .idle
            }
        }
    }
    
    func handleDrop(urls: [URL], onKey key: String) {
        print("[DropzoneManager] handleDrop: key = \(key)")
        if key == "shelf" {
            shelfFiles(urls)
        } else if key.hasPrefix("folder_") {
            let path = String(key.dropFirst(7))
            Task {
                await moveToFolder(urls: urls, path: path, actionKey: key)
            }
        } else if key == "action_airdrop" {
            airdropFiles(urls)
        } else if key == "action_email" {
            emailFiles(urls)
        } else if key == "action_imgur" {
            Task {
                await uploadToImgur(urls)
            }
        } else if key == "action_shortenURL" {
            Task {
                await shortenURL(urls)
            }
        } else if key == "action_copyPath" {
            copyPaths(urls)
        } else if key == "action_zip" {
            Task {
                await zipFiles(urls)
            }
        } else if key == "action_resizeImage" {
            Task {
                await resizeImages(urls)
            }
        } else if key == "action_convertImage" {
            Task {
                await convertImagesToPNG(urls)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared.closeAllPanels()
        }
    }
    
    // Actions implementation
    func copyPaths(_ urls: [URL]) {
        let actionKey = "action_copyPath"
        setProgress(.running("Copying..."), for: actionKey)
        let paths = urls.map { $0.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(paths, forType: .string)
        HapticManager.shared.success()
        setProgress(.success("Copied!"), for: actionKey)
    }
    
    func moveToFolder(urls: [URL], path: String, actionKey: String) async {
        setProgress(.running("Moving..."), for: actionKey)
        let destFolder = URL(fileURLWithPath: path)
        var count = 0
        let fileManager = FileManager.default
        
        for url in urls {
            var dest = destFolder.appendingPathComponent(url.lastPathComponent)
            
            // Safe Duplicate Resolution (Keep Both)
            if fileManager.fileExists(atPath: dest.path) {
                let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
                let pathExtension = url.pathExtension
                var suffix = 1
                repeat {
                    let newName = "\(nameWithoutExtension) (\(suffix))\(pathExtension.isEmpty ? "" : ".\(pathExtension)")"
                    dest = destFolder.appendingPathComponent(newName)
                    suffix += 1
                } while fileManager.fileExists(atPath: dest.path)
            }
            
            do {
                do {
                    try fileManager.moveItem(at: url, to: dest)
                } catch {
                    try fileManager.copyItem(at: url, to: dest)
                    try? fileManager.removeItem(at: url)
                }
                count += 1
            } catch {
                print("Failed to move file \(url.lastPathComponent) to \(path): \(error)")
            }
        }
        
        if count > 0 {
            HapticManager.shared.success()
            setProgress(.success("Moved \(count) files"), for: actionKey)
            
            let content = UNMutableNotificationContent()
            content.title = "FrogDrop"
            content.subtitle = "Files Moved Successfully"
            content.body = "\(count) file(s) moved to \(destFolder.lastPathComponent)."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            Task { try? await UNUserNotificationCenter.current().add(request) }
        } else {
            setProgress(.failure("Error"), for: actionKey)
        }
    }
    
    func airdropFiles(_ urls: [URL]) {
        let actionKey = "action_airdrop"
        setProgress(.running("AirDrop..."), for: actionKey)
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: urls)
        setProgress(.success("Sent!"), for: actionKey)
    }
    
    func emailFiles(_ urls: [URL]) {
        let actionKey = "action_email"
        setProgress(.running("Email..."), for: actionKey)
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .composeEmail)
        sharingService?.perform(withItems: urls)
        setProgress(.success("Composed!"), for: actionKey)
    }
    
    func uploadToImgur(_ urls: [URL]) async {
        let actionKey = "action_imgur"
        guard let url = urls.first else {
            setProgress(.failure("No file"), for: actionKey)
            return
        }
        
        setProgress(.running("Uploading..."), for: actionKey)
        
        Task.detached(priority: .userInitiated) {
            do {
                let fileData = try Data(contentsOf: url)
                let clientID = "4e3b7b25b6a718d"
                var request = URLRequest(url: URL(string: "https://api.imgur.com/3/image")!)
                request.httpMethod = "POST"
                request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
                
                let base64String = fileData.base64EncodedString()
                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var body = Data()
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
                body.append(base64String.data(using: .utf8)!)
                body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
                request.httpBody = body
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                struct ImgurResponse: Codable {
                    struct DataClass: Codable {
                        let link: String?
                    }
                    let data: DataClass?
                    let success: Bool
                }
                
                if let decoded = try? JSONDecoder().decode(ImgurResponse.self, from: data),
                   let link = decoded.data?.link {
                    await MainActor.run {
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(link, forType: .string)
                        HapticManager.shared.success()
                        DropzoneManager.shared.setProgress(.success("Uploaded!"), for: actionKey)
                        
                        let content = UNMutableNotificationContent()
                        content.title = "FrogDrop"
                        content.subtitle = "Imgur Upload Successful"
                        content.body = "Link copied to clipboard!"
                        content.sound = .default
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        Task { try? await UNUserNotificationCenter.current().add(request) }
                    }
                } else {
                    await MainActor.run {
                        DropzoneManager.shared.setProgress(.failure("Error"), for: actionKey)
                    }
                }
            } catch {
                print("Imgur upload error: \(error)")
                await MainActor.run {
                    DropzoneManager.shared.setProgress(.failure("Error"), for: actionKey)
                }
            }
        }
    }
    
    func shortenURL(_ urls: [URL]) async {
        let actionKey = "action_shortenURL"
        guard let url = urls.first else {
            setProgress(.failure("No URL"), for: actionKey)
            return
        }
        
        setProgress(.running("Shortening..."), for: actionKey)
        
        if url.scheme == "http" || url.scheme == "https" {
            let originalString = url.absoluteString
            let tinyURLString = "https://tinyurl.com/api-create?url=\(originalString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            guard let fetchURL = URL(string: tinyURLString) else {
                setProgress(.failure("Invalid URL"), for: actionKey)
                return
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: fetchURL)
                if let shortened = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(shortened, forType: .string)
                    HapticManager.shared.success()
                    setProgress(.success("Shortened!"), for: actionKey)
                    
                    let content = UNMutableNotificationContent()
                    content.title = "FrogDrop"
                    content.subtitle = "URL Shortened"
                    content.body = "Shortened URL copied to clipboard!"
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    Task { try? await UNUserNotificationCenter.current().add(request) }
                } else {
                    setProgress(.failure("Error"), for: actionKey)
                }
            } catch {
                setProgress(.failure("API error"), for: actionKey)
            }
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(url.lastPathComponent, forType: .string)
            setProgress(.success("Copied Name"), for: actionKey)
        }
    }
    
    func zipFiles(_ urls: [URL]) async {
        let actionKey = "action_zip"
        guard !urls.isEmpty else {
            setProgress(.failure("No files"), for: actionKey)
            return
        }
        setProgress(.running("Zipping..."), for: actionKey)
        
        let fileManager = FileManager.default
        let targetDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? urls.first!.deletingLastPathComponent()
        let archiveName = "FrogDrop_Archive_\(Int(Date().timeIntervalSince1970)).zip"
        let zipURL = targetDirectory.appendingPathComponent(archiveName)
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("FrogDrop_Zip_\(UUID().uuidString)")
            
            do {
                try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                for url in urls {
                    let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                    if fileManager.fileExists(atPath: dest.path) {
                        try? fileManager.removeItem(at: dest)
                    }
                    try fileManager.copyItem(at: url, to: dest)
                }
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, zipURL.path]
                
                try process.run()
                process.waitUntilExit()
                
                try? fileManager.removeItem(at: tempDir)
                
                let success = process.terminationStatus == 0
                
                await MainActor.run {
                    if success {
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(zipURL.path, forType: .string)
                        HapticManager.shared.success()
                        DropzoneManager.shared.setProgress(.success("Compressed! → Downloads"), for: actionKey)
                        NSWorkspace.shared.activateFileViewerSelecting([zipURL])
                    } else {
                        DropzoneManager.shared.setProgress(.failure("Error"), for: actionKey)
                    }
                }
            } catch {
                print("Failed to compress files: \(error)")
                try? fileManager.removeItem(at: tempDir)
                await MainActor.run {
                    DropzoneManager.shared.setProgress(.failure("Error"), for: actionKey)
                }
            }
        }
    }
    
    func resizeImages(_ urls: [URL]) async {
        let actionKey = "action_resizeImage"
        guard !urls.isEmpty else {
            setProgress(.failure("No images"), for: actionKey)
            return
        }
        setProgress(.running("Resizing..."), for: actionKey)
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        
        Task.detached(priority: .userInitiated) {
            var count = 0
            for url in urls {
                guard let image = NSImage(contentsOf: url) else { continue }
                let targetWidth: CGFloat = 800
                let currentSize = image.size
                
                guard currentSize.width > 0 && currentSize.height > 0 else { continue }
                
                let scale = targetWidth / currentSize.width
                let targetHeight = currentSize.height * scale
                let newSize = NSSize(width: targetWidth, height: targetHeight)
                
                let newImage = NSImage(size: newSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: newSize),
                           from: NSRect(origin: .zero, size: currentSize),
                           operation: .copy,
                           fraction: 1.0)
                newImage.unlockFocus()
                
                guard let tiffData = newImage.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else { continue }
                
                let filenameWithoutExt = url.deletingPathExtension().lastPathComponent
                let destURL = downloadsDir.appendingPathComponent("\(filenameWithoutExt)_resized.jpg")
                
                do {
                    try jpegData.write(to: destURL)
                    count += 1
                } catch {
                    print("Failed to write resized image: \(error)")
                }
            }
            
            let finalCount = count
            await MainActor.run {
                if finalCount > 0 {
                    HapticManager.shared.success()
                    DropzoneManager.shared.setProgress(.success("Resized → Downloads"), for: actionKey)
                    NSWorkspace.shared.open(downloadsDir)
                } else {
                    DropzoneManager.shared.setProgress(.failure("Failed"), for: actionKey)
                }
            }
        }
    }
    
    func convertImagesToPNG(_ urls: [URL]) async {
        let actionKey = "action_convertImage"
        guard !urls.isEmpty else {
            setProgress(.failure("No images"), for: actionKey)
            return
        }
        setProgress(.running("Converting..."), for: actionKey)
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        
        Task.detached(priority: .userInitiated) {
            var count = 0
            for url in urls {
                guard let image = NSImage(contentsOf: url) else { continue }
                guard let tiffData = image.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapRep.representation(using: .png, properties: [:]) else { continue }
                
                let filenameWithoutExt = url.deletingPathExtension().lastPathComponent
                let destURL = downloadsDir.appendingPathComponent("\(filenameWithoutExt).png")
                
                do {
                    try pngData.write(to: destURL)
                    count += 1
                } catch {
                    print("Failed to convert image: \(error)")
                }
            }
            
            let finalCount = count
            await MainActor.run {
                if finalCount > 0 {
                    HapticManager.shared.success()
                    DropzoneManager.shared.setProgress(.success("Converted → Downloads"), for: actionKey)
                    NSWorkspace.shared.open(downloadsDir)
                } else {
                    DropzoneManager.shared.setProgress(.failure("Failed"), for: actionKey)
                }
            }
        }
    }
    
    func createTempGroupDirectory() -> URL? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("FrogDrop_Group_\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            for url in shelvedFiles {
                let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                try fileManager.createSymbolicLink(at: dest, withDestinationURL: url)
            }
            return tempDir
        } catch {
            print("Failed to create temp group directory: \(error)")
            return nil
        }
    }
}

class DropzoneDragOverlay: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDragEnded: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDragTypes()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDragTypes()
    }
    
    private func registerDragTypes() {
        self.registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
            NSPasteboard.PasteboardType(rawValue: "public.file-url"),
            NSPasteboard.PasteboardType(rawValue: "public.url")
        ])
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DropzoneManager.shared.hoveredActionKey = nil
        onDragExited?()
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        DropzoneManager.shared.hoveredActionKey = nil
        onDragEnded?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = sender.draggingLocation
        let localPoint = self.convert(location, from: nil)
        let key = getActionKey(at: localPoint)
        
        print("[DropzoneDragOverlay] performDragOperation: key = \(String(describing: key))")
        
        guard let key = key else { return false }
        
        let pasteboard = sender.draggingPasteboard
        var urls: [URL] = []
        if let nsurls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls = nsurls
        }
        
        if urls.isEmpty {
            if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String] {
                urls = filenames.map { URL(fileURLWithPath: $0) }
            }
        }
        
        guard !urls.isEmpty else { return false }
        
        DispatchQueue.main.async {
            DropzoneManager.shared.handleDrop(urls: urls, onKey: key)
        }
        
        return true
    }
    
    private func updateHoveredAction(for location: NSPoint) {
        let localPoint = self.convert(location, from: nil)
        let key = getActionKey(at: localPoint)
        if DropzoneManager.shared.hoveredActionKey != key {
            DropzoneManager.shared.hoveredActionKey = key
        }
    }
    
    private func getActionKey(at localPoint: NSPoint) -> String? {
        for (key, rect) in DropzoneManager.shared.registeredFrames {
            if rect.contains(localPoint) {
                return key
            }
        }
        return nil
    }
}

class DropzonePanelContentView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) {
            return hit
        }
        return self
    }
}

class DropzonePanelWindow: NSWindow {
    private var statusItemFrame: NSRect
    private let collapsedHostingView: NSHostingView<CollapsedPanelView>
    private let expandedContainer = NSView()
    private let expandedHostingView: DropzoneHostingView<DropzonePanelView>
    private var isExpanded = false
    
    // Drag state tracking
    var isDragOverPanel = false
    var isDraggingActive = false {
        didSet {
            dragOverlay.isHidden = !isDraggingActive
        }
    }
    private let dragOverlay = DropzoneDragOverlay()
    
    private static func getCollapsedRect(statusItemFrame: NSRect) -> NSRect {
        let width: CGFloat = 80
        let height: CGFloat = 28
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 2,
            width: width,
            height: height
        )
        return rect
    }
    
    private static func getExpandedRect(statusItemFrame: NSRect) -> NSRect {
        let width: CGFloat = 240
        let height: CGFloat = 520
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 2,
            width: width,
            height: height
        )
        return rect
    }
    
    init(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        self.collapsedHostingView = NSHostingView(rootView: CollapsedPanelView())
        self.expandedHostingView = DropzoneHostingView(rootView: DropzonePanelView())
        
        super.init(
            contentRect: Self.getCollapsedRect(statusItemFrame: statusItemFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let contentView = DropzonePanelContentView()
        self.contentView = contentView
        
        collapsedHostingView.frame = contentView.bounds
        collapsedHostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(collapsedHostingView)
        
        expandedContainer.frame = contentView.bounds
        expandedContainer.autoresizingMask = [.width, .height]
        expandedContainer.wantsLayer = true
        expandedContainer.layer?.cornerRadius = 16
        expandedContainer.layer?.masksToBounds = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.frame = expandedContainer.bounds
        effectView.autoresizingMask = [.width, .height]
        
        expandedHostingView.frame = expandedContainer.bounds
        expandedHostingView.autoresizingMask = [.width, .height]
        
        expandedContainer.addSubview(effectView)
        expandedContainer.addSubview(expandedHostingView)
        contentView.addSubview(expandedContainer)
        
        dragOverlay.frame = contentView.bounds
        dragOverlay.autoresizingMask = [.width, .height]
        dragOverlay.onDragEntered = { [weak self] in
            self?.isDragOverPanel = true
            self?.slideIn()
        }
        dragOverlay.onDragExited = { [weak self] in
            self?.isDragOverPanel = false
            self?.slideOut()
        }
        dragOverlay.onDragEnded = { [weak self] in
            self?.isDragOverPanel = false
            self?.slideOut(force: true)
        }
        dragOverlay.isHidden = true
        contentView.addSubview(dragOverlay)
        
        collapsedHostingView.isHidden = false
        expandedContainer.isHidden = true
    }
    
    func slideIn() {
        guard !isExpanded else { return }
        isExpanded = true
        self.hasShadow = true
        self.orderFrontRegardless()
        
        collapsedHostingView.isHidden = true
        expandedContainer.isHidden = false
        
        let targetRect = Self.getExpandedRect(statusItemFrame: self.statusItemFrame)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 0.85, 0.35, 1.1)
            self.animator().setFrame(targetRect, display: true)
        }
        HapticManager.shared.tick()
    }
    
    func slideOut(force: Bool = false) {
        guard isExpanded else { return }
        
        if !force {
            let mouseLoc = NSEvent.mouseLocation
            if self.frame.contains(mouseLoc) {
                print("[DropzonePanelWindow] slideOut skipped: Mouse is inside panel frame")
                return
            }
            if let statusItemWindow = AppDelegate.shared.statusItem?.button?.window,
               statusItemWindow.frame.contains(mouseLoc) {
                print("[DropzonePanelWindow] slideOut skipped: Mouse is inside status bar button")
                return
            }
        }
        
        isExpanded = false
        self.hasShadow = false
        self.isDragOverPanel = false
        
        let targetRect = Self.getCollapsedRect(statusItemFrame: self.statusItemFrame)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetRect, display: true)
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.collapsedHostingView.isHidden = false
            self.expandedContainer.isHidden = true
            self.orderOut(nil)
        }
    }
    
    func showCollapsedIndicator() {
        guard !isExpanded else { return }
        isDraggingActive = true
        self.orderFrontRegardless()
    }
    
    func hideCollapsedIndicator() {
        guard !isExpanded else { return }
        isDraggingActive = false
        self.orderOut(nil)
    }
    
    func updatePosition(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        let targetRect = isExpanded ? Self.getExpandedRect(statusItemFrame: statusItemFrame) : Self.getCollapsedRect(statusItemFrame: statusItemFrame)
        self.setFrame(targetRect, display: true)
    }
}

struct CollapsedPanelView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.green)
            Text("DROP")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(0.5)
        }
        .frame(width: 70, height: 20)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.22, green: 0.72, blue: 0.42).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: Color(red: 0.22, green: 0.72, blue: 0.42).opacity(0.2), radius: 3)
        .frame(width: 80, height: 28)
    }
}

struct DropzonePanelView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isShowingSettings = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Elegant Header bar
                HStack {
                    Button(action: {
                        isShowingSettings = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isShowingSettings, arrowEdge: .top) {
                        MenuBarSettingsView()
                    }
                    
                    Spacer()
                    
                    // Title
                    Text("FROG DROP")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .tracking(1.0)
                    
                    Spacer()
                    
                    Button(action: {
                        isShowingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 38)
                .padding(.horizontal, 8)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                
                // Dropzone Grid (Dragging mode is true in the slide-in panel)
                ScrollView {
                    DropzoneGrid(isDraggingMode: true)
                }
            }
            .frame(width: 240, height: 520)
            
            if manager.isShowingCombinePopover {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    }
                
                CombinePopoverView(
                    selectedIDs: $manager.selectedGroupIDs,
                    onCombine: {
                        manager.combineGroups(withIDs: manager.selectedGroupIDs)
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    },
                    onCancel: {
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct DropzoneGrid: View {
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    // Invisible buttons for keyboard shortcuts 1-9
                    ForEach(0..<min(manager.enabledActions.count, 9), id: \.self) { idx in
                        let actionKey = "action_" + manager.enabledActions[idx]
                        Button("") {
                            if !manager.shelvedFiles.isEmpty {
                                manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                manager.clearShelf()
                            } else {
                                selectFilesAndRun(actionKey: actionKey)
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(49 + idx)!)), modifiers: [])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    }
                    
                    // Shelf Header (only shown when items are shelved)
                    if !manager.shelvedGroups.isEmpty {
                        HStack {
                            Text("SHELF (\(manager.shelvedGroups.count) group\(manager.shelvedGroups.count == 1 ? "" : "s"), \(manager.shelvedFiles.count) file\(manager.shelvedFiles.count == 1 ? "" : "s"))")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            Spacer()
                            
                            if manager.shelvedGroups.count > 1 {
                                Button(action: {
                                    manager.selectedGroupIDs = Set(manager.shelvedGroups.map { $0.id })
                                    withAnimation {
                                        manager.isShowingCombinePopover = true
                                    }
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "square.stack.3d.up")
                                            .font(.system(size: 8))
                                        Text("Combine")
                                            .font(.system(size: 8, weight: .semibold))
                                    }
                                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.12))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: { manager.clearShelf() }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                    Text("Clear")
                                        .font(.system(size: 8, weight: .semibold))
                                }
                                .foregroundColor(.red.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    }
                    
                    // Core Row: Add to Grid, Drop Bar, Shelved Files
                    LazyVGrid(columns: columns, spacing: 12) {
                        if isDraggingMode {
                            // Drop Bar
                            DropzoneCoreTargetView(
                                title: "Drop Bar",
                                icon: "arrow.down",
                                isHovered: manager.hoveredActionKey == "shelf",
                                isDashed: true
                            )
                            .background(FrameRegistrationHelper(key: "shelf"))
                        } else {
                            // Add to Grid
                            Button(action: {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.prompt = "Add to Grid"
                                panel.message = "Choose a folder to add to your Dropzone grid"
                                if panel.runModal() == .OK, let url = panel.url {
                                    let newItem = DropzoneItem(type: "folder", name: url.lastPathComponent, path: url.path)
                                    manager.customFolders.append(newItem)
                                    manager.saveSettings()
                                    HapticManager.shared.success()
                                }
                            }) {
                                DropzoneCoreTargetView(
                                    title: "Add to Grid",
                                    icon: "plus",
                                    isHovered: manager.hoveredActionKey == "addGrid",
                                    isDashed: true
                                )
                            }
                            .buttonStyle(.plain)
                            .background(FrameRegistrationHelper(key: "addGrid"))
                        }
                        
                        // Each ShelfGroup = one slot (single file or N Items fan card)
                        ForEach(Array(manager.shelvedGroups.enumerated()), id: \.element.id) { idx, group in
                            ShelfGroupCard(group: group, groupIndex: idx, isDraggingMode: isDraggingMode)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                
                // FOLDERS / APPS (Always shown, interactive when not dragging)
                if !manager.customFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FOLDERS / APPS")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(manager.customFolders) { folder in
                                CustomFolderCellView(
                                    folder: folder,
                                    isDraggingMode: isDraggingMode
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                
                // ACTIONS (Always shown, interactive when not dragging)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIONS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        if manager.enabledActions.contains("airdrop") {
                            let actionKey = "action_airdrop"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "AirDrop",
                                    icon: "antenna.radiowaves.left.and.right",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "AirDrop",
                                        icon: "antenna.radiowaves.left.and.right",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("email") {
                            let actionKey = "action_email"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Email",
                                    icon: "envelope.fill",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Email",
                                        icon: "envelope.fill",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("imgur") {
                            let actionKey = "action_imgur"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Imgur",
                                    icon: "photo.fill",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Imgur",
                                        icon: "photo.fill",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("shortenURL") {
                            let actionKey = "action_shortenURL"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Shorten URL",
                                    icon: "link",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Shorten URL",
                                        icon: "link",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("zip") {
                            let actionKey = "action_zip"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Zip Files",
                                    icon: "archivebox.fill",
                                    iconColor: .orange,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Zip Files",
                                        icon: "archivebox.fill",
                                        iconColor: .orange,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("resizeImage") {
                            let actionKey = "action_resizeImage"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Resize Image",
                                    icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Resize Image",
                                        icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("convertImage") {
                            let actionKey = "action_convertImage"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Convert to PNG",
                                    icon: "photo.on.rectangle.angled",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Convert to PNG",
                                        icon: "photo.on.rectangle.angled",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("copyPath") {
                            let actionKey = "action_copyPath"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Copy Path",
                                    icon: "doc.on.doc.fill",
                                    iconColor: .purple,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Copy Path",
                                        icon: "doc.on.doc.fill",
                                        iconColor: .purple,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            
            // Popover removed from inside ScrollView/Grid to prevent clipping.
        }
    }

    private func selectFilesAndRun(actionKey: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = "Run Action"
        panel.message = "Select files or folders to run this action"
        
        let response = panel.runModal()
        if response == .OK {
            manager.handleDrop(urls: panel.urls, onKey: actionKey)
        }
    }

    private func handleSwiftUIDrop(providers: [NSItemProvider], onKey: String) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                manager.shelvedGroups.removeAll(where: { group in group.files.contains(where: { f in urls.contains(where: { $0.path == f.path }) }) })
                manager.handleDrop(urls: urls, onKey: onKey)
            }
            manager.hoveredActionKey = nil
        }
        return true
    }
}

// MARK: - ShelfGroupCard
struct ShelfGroupCard: View {
    let group: ShelfGroup
    let groupIndex: Int
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if group.files.count == 1, let url = group.files.first {
                    singleCard(url: url)
                } else {
                    fanCard()
                }
                if !isDraggingMode {
                    Button(action: { manager.deleteShelfGroup(at: groupIndex) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .background(Circle().fill(Color.black))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -4)
                }
            }
            if group.files.count == 1, let url = group.files.first {
                Text(url.lastPathComponent)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 62)
            } else {
                Text("\(group.files.count) Items")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                    .frame(width: 62)
            }
        }
        .onTapGesture(count: 2) {
            if group.files.count == 1, let url = group.files.first { NSWorkspace.shared.open(url) }
        }
        .overlay(CardDragTrackerView(group: group))
        .contextMenu {
            if group.files.count == 1, let url = group.files.first {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Copy Path") {
                    NSPasteboard.general.declareTypes([.string], owner: nil)
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button("Open") { NSWorkspace.shared.open(url) }
                Divider()
                Button("Move to Trash") {
                    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    manager.deleteShelfGroup(at: groupIndex)
                }
            }
            Button("Remove from Shelf") { manager.deleteShelfGroup(at: groupIndex) }
            if manager.shelvedGroups.count > 1 {
                Divider()
                Button("Combine with Others") { manager.combineAllGroups() }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            var urls: [URL] = []
            let dispatchGroup = DispatchGroup()
            for provider in providers {
                dispatchGroup.enter()
                _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                    if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                        urls.append(url)
                    }
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.wait()
            guard !urls.isEmpty else { return false }
            
            DispatchQueue.main.async {
                manager.combineFiles(urls, intoGroupAt: groupIndex)
            }
            return true
        }
    }

    @ViewBuilder
    private func singleCard(url: URL) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.06))
            .frame(width: 54, height: 54)
            .overlay(
                Group {
                    if let img = group.thumbnails[url] {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable().aspectRatio(contentMode: .fit).frame(width: 34, height: 34)
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
    }

    @ViewBuilder
    private func fanCard() -> some View {
        let showing = min(3, group.files.count)
        ZStack {
            ForEach(0..<showing, id: \.self) { i in
                let url = group.files[i]
                let angle = Double(i - 1) * 12.0
                let xOff = CGFloat(i - 1) * 7
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.12, green: 0.18, blue: 0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Group {
                            if let img = group.thumbnails[url] {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                            }
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.4), lineWidth: 0.8))
                    .rotationEffect(.degrees(angle))
                    .offset(x: xOff)
                    .zIndex(Double(i))
            }
        }
        .frame(width: 66, height: 54)
    }
}

struct CustomFolderCellView: View {
    let folder: DropzoneItem
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        let path = folder.path ?? ""
        let key = "folder_\(path)"
        
        if isDraggingMode {
            DropzoneTargetView(
                title: folder.name,
                icon: "folder.fill",
                iconColor: .blue,
                isHovered: manager.hoveredActionKey == key
            )
            .background(FrameRegistrationHelper(key: key))
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { manager.hoveredActionKey == key },
                set: { targeted in manager.hoveredActionKey = targeted ? key : nil }
            )) { providers in
                handleSwiftUIDrop(providers: providers, onKey: key)
            }
        } else {
            Button(action: {
                if !manager.shelvedFiles.isEmpty {
                    manager.handleDrop(urls: manager.shelvedFiles, onKey: key)
                    manager.clearShelf()
                } else {
                    if !path.isEmpty {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                }
            }) {
                DropzoneTargetView(
                    title: folder.name,
                    icon: "folder.fill",
                    iconColor: .blue,
                    isHovered: manager.hoveredActionKey == key
                )
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { manager.hoveredActionKey == key },
                set: { targeted in manager.hoveredActionKey = targeted ? key : nil }
            )) { providers in
                handleSwiftUIDrop(providers: providers, onKey: key)
            }
        }
    }
    
    private func handleSwiftUIDrop(providers: [NSItemProvider], onKey: String) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                manager.shelvedGroups.removeAll(where: { group in group.files.contains(where: { f in urls.contains(where: { $0.path == f.path }) }) })
                manager.handleDrop(urls: urls, onKey: onKey)
            }
            manager.hoveredActionKey = nil
        }
        return true
    }
}

struct DropzoneCoreTargetView: View {
    let title: String
    let icon: String
    let isHovered: Bool
    let isDashed: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isDashed {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.green : Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: isHovered ? 1.5 : 1, dash: [4, 4])
                        )
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(12)
                        .frame(width: 50, height: 50)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovered ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isHovered ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 0.8)
                        )
                }
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isHovered ? .green : .primary)
            }
            
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? .green : .secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 68)
    }
}

struct DropzoneTargetView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isHovered: Bool
    var actionKey: String? = nil
    
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        let progressState = actionKey.flatMap { manager.actionProgress[$0] } ?? .idle
        
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isHovered ? iconColor.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(isHovered ? iconColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                    )
                
                switch progressState {
                case .idle:
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isHovered ? iconColor : .primary)
                case .running:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            let displayTitle: String = {
                switch progressState {
                case .idle:
                    return title
                case .running(let msg):
                    return msg
                case .success(let msg):
                    return msg
                case .failure(let msg):
                    return msg
                }
            }()
            
            Text(displayTitle)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? iconColor : .secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 68)
    }
}

// MARK: - Window Bounds Reader (fixes coordinate mismatch in FrameRegistrationHelper)
class BoundsReadingView: NSView {
    var onBoundsUpdate: ((NSRect) -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBounds()
        
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
        if let window = window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }
    }
    
    @objc private func windowDidResize() {
        updateBounds()
    }
    
    private func updateBounds() {
        guard let window = window else { return }
        let bounds = window.contentView?.bounds ?? window.frame
        onBoundsUpdate?(bounds)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct WindowBoundsReader: NSViewRepresentable {
    @Binding var bounds: NSRect?
    
    func makeNSView(context: Context) -> BoundsReadingView {
        let view = BoundsReadingView()
        view.onBoundsUpdate = { newBounds in
            self.bounds = newBounds
        }
        return view
    }
    
    func updateNSView(_ nsView: BoundsReadingView, context: Context) {}
}

struct FrameRegistrationHelper: View {
    let key: String
    @State private var windowBounds: NSRect?
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .background(WindowBoundsReader(bounds: $windowBounds))
                .onAppear {
                    register(geo: geo)
                }
                .onChange(of: geo.frame(in: .global)) {
                    register(geo: geo)
                }
                .onChange(of: windowBounds) {
                    register(geo: geo)
                }
        }
    }
    
    private func register(geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let nsRect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        
        // Use actual window content height for accurate coordinate conversion
        let contentHeight = windowBounds?.height ?? 380
        
        let appKitRect = NSRect(
            x: nsRect.origin.x,
            y: contentHeight - nsRect.origin.y - nsRect.size.height,
            width: nsRect.size.width,
            height: nsRect.size.height
        )
        
        DispatchQueue.main.async {
            DropzoneManager.shared.registerFrame(appKitRect, for: key)
        }
    }
}

struct MenuBarSettingsView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab = 0 // 0 = General, 1 = Grid, 2 = Rules
    @State private var newRuleAppName = ""
    @State private var newRuleType: ClipboardPreferenceRule.RuleType = .temporary
    @State private var runningApps: [String] = []
    @State private var selectedRunningApp = ""
    
    // Haptic level state
    @State private var hapticLevel: HapticManager.HapticLevel = HapticManager.shared.level
    @State private var isLaunchAtLoginEnabled = false
    @AppStorage("uiDimOpacity") private var uiDimOpacity: Double = 0.0
    
    // Icon Style state
    @AppStorage("menuBarIconStyle") var menuBarIconStyle: String = "frog"
    @AppStorage("menuBarCustomImagePath") var menuBarCustomImagePath: String = ""
    
    private func selectCustomImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                let targetSize = NSSize(width: 48, height: 48)
                let newImage = NSImage(size: targetSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: targetSize))
                newImage.unlockFocus()
                
                if let tiff = newImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    
                    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("FrogDrop") ?? FileManager.default.temporaryDirectory
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let path = dir.appendingPathComponent("custom_icon.png")
                    
                    try? png.write(to: path)
                    menuBarCustomImagePath = path.path
                    menuBarIconStyle = "custom"
                    HapticManager.shared.success()
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimalist Tab Bar
            HStack(spacing: 16) {
                TabButton(title: "General", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 0
                    }
                }
                TabButton(title: "Grid", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
                TabButton(title: "Rules", isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 2
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Tab Contents
            ZStack {
                if selectedTab == 0 {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        
                        // Menu Bar Icon Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MENU BAR ICON")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                            
                            HStack(spacing: 4) {
                                let options = [
                                    ("frog", "Frog", "face.smiling"),
                                    ("minimal", "Minimal", "square.and.arrow.down.fill"),
                                    ("custom", "Custom", "photo")
                                ]
                                ForEach(options, id: \.0) { opt in
                                    Button(action: {
                                        menuBarIconStyle = opt.0
                                        HapticManager.shared.click()
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: opt.2)
                                                .font(.system(size: 14))
                                            Text(opt.1)
                                                .font(.system(size: 10, weight: menuBarIconStyle == opt.0 ? .bold : .medium, design: .rounded))
                                        }
                                        .foregroundColor(menuBarIconStyle == opt.0 ? .black : .primary)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(menuBarIconStyle == opt.0 ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if menuBarIconStyle == "custom" {
                                HStack {
                                    Button("Choose Image...", action: selectCustomImage)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.white.opacity(0.08)).cornerRadius(5)
                                        .buttonStyle(.plain)
                                    
                                    if !menuBarCustomImagePath.isEmpty {
                                        Button(action: {
                                            menuBarCustomImagePath = ""
                                            UserDefaults.standard.removeObject(forKey: "menuBarCustomImagePath")
                                            HapticManager.shared.click()
                                        }) {
                                            Image(systemName: "trash").foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HAPTICS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                            
                            HStack(spacing: 4) {
                                ForEach(HapticManager.HapticLevel.allCases, id: \.self) { val in
                                    Button(action: {
                                        hapticLevel = val
                                        HapticManager.shared.level = val
                                        HapticManager.shared.click()
                                    }) {
                                        Text(val.rawValue)
                                            .font(.system(size: 11, weight: hapticLevel == val ? .bold : .medium, design: .rounded))
                                            .foregroundColor(hapticLevel == val ? .black : .primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity)
                                            .background(hapticLevel == val ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("TEMP EXPIRATION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                Spacer()
                                Text("\(Int(clipboardManager.tempDuration))s")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            
                            Slider(value: $clipboardManager.tempDuration, in: 15...120, step: 5)
                                .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                .onChange(of: clipboardManager.tempDuration) { _, _ in
                                    clipboardManager.saveSettings()
                                }
                            
                            Text("Auto-delete items copied from temporary applications.")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("STARTUP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                            
                            Toggle(isOn: Binding(
                                get: { isLaunchAtLoginEnabled },
                                set: { newValue in
                                    toggleLaunchAtLogin(newValue)
                                }
                            )) {
                                Text("Launch automatically at login")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .toggleStyle(.checkbox)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APPEARANCE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.0)
                            
                            Text("Popup darkness")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Slider(value: $uiDimOpacity, in: 0.0...1.0, step: 0.05)
                                    .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                Image(systemName: "moon")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(uiDimOpacity < 0.15 ? "Glass (Fully Transparent)" : uiDimOpacity < 0.45 ? "Light" : uiDimOpacity < 0.75 ? "Medium" : "Dark")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                        }
                    }
                    .padding(16)
                }
                .transition(.opacity)

                } else if selectedTab == 1 {
                    // Grid Folders & Actions
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FOLDERS & APPS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ForEach(manager.customFolders) { folder in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue.opacity(0.8))
                                            .font(.system(size: 11))
                                        Text(folder.name)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Button(action: {
                                            manager.removeFolder(id: folder.id)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.7))
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                                
                                Button(action: {
                                    selectFolder()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Folder...")
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BUILT-IN ACTIONS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ToggleActionRow(title: "AirDrop", actionType: "airdrop")
                                ToggleActionRow(title: "Email", actionType: "email")
                                ToggleActionRow(title: "Imgur Upload", actionType: "imgur")
                                ToggleActionRow(title: "Shorten URL", actionType: "shortenURL")
                                ToggleActionRow(title: "Zip Files", actionType: "zip")
                                ToggleActionRow(title: "Resize Image", actionType: "resizeImage")
                                ToggleActionRow(title: "Convert to PNG", actionType: "convertImage")
                                ToggleActionRow(title: "Copy Path", actionType: "copyPath")
                            }
                        }
                        .padding(16)
                    }
                    .transition(.opacity)
                } else {
                    // Application Rules
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("APP PREFERENCES")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ForEach(clipboardManager.customRules) { rule in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(rule.appName)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                            Text(rule.ruleType.rawValue.capitalized)
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(rule.ruleType == .temporary ? .orange : (rule.ruleType == .save ? .green : .red))
                                        }
                                        
                                        Spacer()
                                        
                                        Menu {
                                            Button("Save (Permanent)") {
                                                clipboardManager.updateRule(id: rule.id, newType: .save)
                                            }
                                            Button("Temporary") {
                                                clipboardManager.updateRule(id: rule.id, newType: .temporary)
                                            }
                                            Button("Ignore (Don't Save)") {
                                                clipboardManager.updateRule(id: rule.id, newType: .ignore)
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle.fill")
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .font(.system(size: 14))
                                        }
                                        .menuStyle(.borderlessButton)
                                        .frame(width: 20)
                                        
                                        Button(action: {
                                            clipboardManager.removeRule(id: rule.id)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(16)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        // Add rule block
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ADD NEW PREFERENCE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 6) {
                                if !runningApps.isEmpty {
                                    Picker("", selection: $selectedRunningApp) {
                                        ForEach(runningApps, id: \.self) { app in
                                            Text(app).tag(app)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                } else {
                                    TextField("App Name...", text: $newRuleAppName)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, design: .rounded))
                                        .padding(5)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                
                                Picker("", selection: $newRuleType) {
                                    Text("Temp").tag(ClipboardPreferenceRule.RuleType.temporary)
                                    Text("Ignore").tag(ClipboardPreferenceRule.RuleType.ignore)
                                }
                                .labelsHidden()
                                .frame(width: 60)
                                
                                Button(action: {
                                    let appToSave = runningApps.isEmpty ? newRuleAppName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedRunningApp
                                    if !appToSave.isEmpty {
                                        clipboardManager.addRule(appName: appToSave, ruleType: newRuleType)
                                        newRuleAppName = ""
                                        HapticManager.shared.success()
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.015))
                    }
                    .transition(.opacity)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.15, green: 0.85, blue: 0.45))
            .padding(.vertical, 8)
        }
        .frame(width: 260, height: 330)
        .background(Color.black.opacity(uiDimOpacity))
        .onAppear {
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { $0.localizedName }
                .filter { !$0.isEmpty }
            let uniqueApps = Array(Set(apps)).sorted()
            self.runningApps = uniqueApps
            if let first = uniqueApps.first {
                self.selectedRunningApp = first
            }
            isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                isLaunchAtLoginEnabled = true
            } catch {
                print("Failed to register Launch at Login: \(error)")
                isLaunchAtLoginEnabled = false
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                isLaunchAtLoginEnabled = false
            } catch {
                print("Failed to unregister Launch at Login: \(error)")
                isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
    
    // TabButton helper component
    struct TabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary)
                    
                    Circle()
                        .fill(isSelected ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let folderName = url.lastPathComponent
            manager.addFolder(name: folderName, path: url.path)
        }
    }
}

struct ToggleActionRow: View {
    let title: String
    let actionType: String
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
            Spacer()
            Toggle("", isOn: Binding(
                get: { manager.enabledActions.contains(actionType) },
                set: { enabled in manager.toggleAction(actionType, enabled: enabled) }
            ))
            .toggleStyle(.switch)
        }
    }
}

struct CombinePopoverView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @Binding var selectedIDs: Set<UUID>
    var onCombine: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMBINE GROUPS")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 4)
            
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(manager.shelvedGroups) { group in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedIDs.contains(group.id) },
                                set: { selected in
                                    if selected {
                                        selectedIDs.insert(group.id)
                                    } else {
                                        selectedIDs.remove(group.id)
                                    }
                                }
                            )) {
                                HStack(spacing: 4) {
                                    if let firstURL = group.files.first {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue)
                                        Text(firstURL.lastPathComponent)
                                            .font(.system(size: 9, weight: .medium))
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                    }
                                    if group.files.count > 1 {
                                        Text("(+\(group.files.count - 1))")
                                            .font(.system(size: 7))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxHeight: 120)
            
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onCombine) {
                    Text("Combine")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .foregroundColor(.black)
                        .background(Color.green)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(selectedIDs.count < 2)
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(Color.clear)
    }
}

class DraggingSource: NSObject, NSDraggingSource {
    static let shared = DraggingSource()
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                if let group = DropzoneManager.shared.currentlyDraggingGroup {
                    DropzoneManager.shared.deleteShelfGroup(where: { $0.id == group.id })
                    DropzoneManager.shared.currentlyDraggingGroup = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared.closeAllPanels()
        }
    }
}

class DropzoneHostingView<Content: View>: NSHostingView<Content> {
}

struct CardDragTrackerView: NSViewRepresentable {
    let group: ShelfGroup
    
    func makeNSView(context: Context) -> DragTrackerNSView {
        let view = DragTrackerNSView()
        view.group = group
        return view
    }
    
    func updateNSView(_ nsView: DragTrackerNSView, context: Context) {
        nsView.group = group
    }
}

class DragTrackerNSView: NSView {
    var group: ShelfGroup?
    private var mouseDownEvent: NSEvent?
    private var isDragging = false
    
    override func mouseDown(with event: NSEvent) {
        self.mouseDownEvent = event
        self.isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent = mouseDownEvent, !isDragging else {
            super.mouseDragged(with: event)
            return
        }
        
        let downPoint = mouseDownEvent.locationInWindow
        let currentPoint = event.locationInWindow
        let dx = currentPoint.x - downPoint.x
        let dy = currentPoint.y - downPoint.y
        let distance = sqrt(dx*dx + dy*dy)
        
        if distance > 5 {
            self.isDragging = true
            self.mouseDownEvent = nil
            
            guard let group = group else { return }
            
            DropzoneManager.shared.currentlyDraggingGroup = group
            
            let draggingItems = group.files.map { url -> NSDraggingItem in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                let dragImage = group.thumbnails[url] ?? NSWorkspace.shared.icon(forFile: url.path)
                
                let convertedLoc = self.convert(event.locationInWindow, from: nil)
                let frame = NSRect(
                    x: convertedLoc.x - 16,
                    y: convertedLoc.y - 16,
                    width: 32,
                    height: 32
                )
                item.setDraggingFrame(frame, contents: dragImage)
                return item
            }
            
            self.beginDraggingSession(with: draggingItems, event: event, source: DraggingSource.shared)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let mouseDownEvent = mouseDownEvent, !isDragging {
            self.isHidden = true
            if let parent = self.superview,
               let hitView = parent.hitTest(mouseDownEvent.locationInWindow) {
                self.isHidden = false
                hitView.mouseDown(with: mouseDownEvent)
                hitView.mouseUp(with: event)
            } else {
                self.isHidden = false
            }
        }
        self.mouseDownEvent = nil
        self.isDragging = false
    }
}
