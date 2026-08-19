import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import QuickLookThumbnailing

@MainActor class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    @Published var shelvedGroups: [ShelfGroup] = []
    @Published var currentlyDraggingGroup: ShelfGroup? = nil
    var shelvedFiles: [URL] { shelvedGroups.flatMap { $0.files } } // compat shim
    @Published var hoveredActionKey: String? = nil
    @Published var customFolders: [DropzoneItem] = []
    @Published var enabledActions: [String] = ["inspectEXIF", "ocr", "webp", "compress", "stripMetadata", "mergePDF", "pickColor", "airdrop", "zip", "email", "shortenURL", "resizeImage", "convertImage", "copyPath", "openPath"]
    @Published var lastDropTime: Date? = nil
    @Published var registeredFrames: [String: NSRect] = [:]
    @Published var actionProgress: [String: TaskProgressState] = [:]
    @Published var isShowingCombinePopover = false
    @Published var selectedGroupIDs: Set<UUID> = []
    
    private let foldersKey = "frogdrop.customFolders"
    private let actionsKey = "frogdrop.enabledActions"
    // All possible actions — always merged in
    private let allActions = ["inspectEXIF", "ocr", "webp", "compress", "stripMetadata", "mergePDF", "pickColor", "airdrop", "zip", "email", "shortenURL", "resizeImage", "convertImage", "copyPath", "openPath"]
    
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
        
        if let savedActions = UserDefaults.standard.stringArray(forKey: actionsKey) {
            var merged = allActions.filter { !savedActions.contains($0) }
            for a in savedActions {
                if allActions.contains(a) && !merged.contains(a) {
                    merged.append(a)
                }
            }
            self.enabledActions = merged
        } else {
            self.enabledActions = allActions
        }
        UserDefaults.standard.set(enabledActions, forKey: actionsKey)
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
        let group = ShelfGroup(files: urls)
        shelvedGroups.append(group)
        lastDropTime = Date()
        HapticManager.shared.success()
        
        let groupID = group.id
        for url in urls {
            Task {
                if let thumb = await ShelfGroup.generateThumb(for: url) {
                    await MainActor.run {
                        if let index = self.shelvedGroups.firstIndex(where: { $0.id == groupID }) {
                            self.shelvedGroups[index].thumbnails[url] = thumb
                        }
                    }
                }
            }
        }
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
        shelvedGroups[index] = group
        HapticManager.shared.success()
        
        let groupID = group.id
        for url in newFiles {
            Task {
                if let thumb = await ShelfGroup.generateThumb(for: url) {
                    await MainActor.run {
                        if let idx = self.shelvedGroups.firstIndex(where: { $0.id == groupID }) {
                            self.shelvedGroups[idx].thumbnails[url] = thumb
                        }
                    }
                }
            }
        }
    }
    
    func deleteShelfGroup(at index: Int) {
        if index >= 0 && index < shelvedGroups.count {
            shelvedGroups.remove(at: index)
        }
        if shelvedGroups.isEmpty { lastDropTime = nil }
    }
    
    func removeFileFromShelf(_ url: URL, fromGroupId groupId: UUID? = nil) {
        if let groupId = groupId {
            if let idx = shelvedGroups.firstIndex(where: { $0.id == groupId }) {
                shelvedGroups[idx].files.removeAll(where: { $0 == url })
                shelvedGroups[idx].thumbnails.removeValue(forKey: url)
            }
        } else {
            for i in 0..<shelvedGroups.count {
                if shelvedGroups[i].files.contains(url) {
                    shelvedGroups[i].files.removeAll(where: { $0 == url })
                    shelvedGroups[i].thumbnails.removeValue(forKey: url)
                }
            }
        }
        shelvedGroups.removeAll(where: { $0.files.isEmpty })
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
        
        shelvedGroups = [combinedGroup]
        HapticManager.shared.success()
        
        let groupID = combinedGroup.id
        for url in uniqueFiles {
            if combinedGroup.thumbnails[url] == nil {
                Task {
                    if let thumb = await ShelfGroup.generateThumb(for: url) {
                        await MainActor.run {
                            if let idx = self.shelvedGroups.firstIndex(where: { $0.id == groupID }) {
                                self.shelvedGroups[idx].thumbnails[url] = thumb
                            }
                        }
                    }
                }
            }
        }
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
        
        remainingGroups.append(combinedGroup)
        self.shelvedGroups = remainingGroups
        HapticManager.shared.success()
        
        let groupID = combinedGroup.id
        for url in uniqueFiles {
            if combinedGroup.thumbnails[url] == nil {
                Task {
                    if let thumb = await ShelfGroup.generateThumb(for: url) {
                        await MainActor.run {
                            if let idx = self.shelvedGroups.firstIndex(where: { $0.id == groupID }) {
                                self.shelvedGroups[idx].thumbnails[url] = thumb
                            }
                        }
                    }
                }
            }
        }
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
        } else if key == "action_inspectEXIF" {
            Task {
                await inspectEXIF(urls)
            }
        } else if key == "action_ocr" {
            Task {
                await extractTextOCR(urls)
            }
        } else if key == "action_webp" {
            Task {
                await convertImagesToWebP(urls)
            }
        } else if key == "action_compress" {
            Task {
                await compressImages(urls)
            }
        } else if key == "action_stripMetadata" {
            Task {
                await stripMetadata(urls)
            }
        } else if key == "action_mergePDF" {
            Task {
                await mergePDFs(urls)
            }
        } else if key == "action_pickColor" {
            Task {
                await pickScreenColor()
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
        } else if key == "action_openPath" {
            openPaths(urls)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared.closeAllPanels()
        }
    }
    
    // Actions implementation
    func openPaths(_ urls: [URL]) {
        let actionKey = "action_openPath"
        setProgress(.running(String(localized: "dropzone.manager.status.opening", defaultValue: "Opening...", comment: "Toast status shown while opening a file or folder path")), for: actionKey)
        var openedCount = 0
        for url in urls {
            if NSWorkspace.shared.open(url) {
                openedCount += 1
            }
        }
        if openedCount > 0 {
            HapticManager.shared.success()
            setProgress(.success(String(localized: "dropzone.manager.status.opened.path", defaultValue: "Opened!", comment: "Toast status shown after successfully opening a path")), for: actionKey)
        } else {
            HapticManager.shared.click()
            setProgress(.failure(String(localized: "dropzone.manager.status.error.open-path", defaultValue: "Error", comment: "Toast title shown when opening a path fails")), for: actionKey)
        }
    }
    
    func openPathFromClipboard() {
        let actionKey = "action_openPath"
        setProgress(.running(String(localized: "dropzone.manager.status.reading", defaultValue: "Reading...", comment: "Toast status shown while reading path contents")), for: actionKey)
        let pasteboard = NSPasteboard.general
        if let clipboardText = pasteboard.string(forType: .string) {
            let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let expanded = (trimmed as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded)
                if FileManager.default.fileExists(atPath: url.path) {
                    if NSWorkspace.shared.open(url) {
                        HapticManager.shared.success()
                        setProgress(.success(String(localized: "dropzone.manager.status.opened.file", defaultValue: "Opened!", comment: "Toast status shown after successfully opening a file")), for: actionKey)
                        return
                    }
                }
            }
        }
        HapticManager.shared.click()
        setProgress(.failure(String(localized: "dropzone.manager.status.invalid-path", defaultValue: "Invalid Path", comment: "Toast status shown when provided path is invalid")), for: actionKey)
    }
    
    func copyPaths(_ urls: [URL]) {
        let actionKey = "action_copyPath"
        setProgress(.running(String(localized: "dropzone.manager.status.copying", defaultValue: "Copying...", comment: "Toast status shown while copying files")), for: actionKey)
        let paths = urls.map { $0.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(paths, forType: .string)
        HapticManager.shared.success()
        setProgress(.success(String(localized: "dropzone.manager.status.copied", defaultValue: "Copied!", comment: "Toast status shown after files are copied")), for: actionKey)
    }
    
    func moveToFolder(urls: [URL], path: String, actionKey: String) async {
        setProgress(.running(String(localized: "dropzone.manager.status.moving", defaultValue: "Moving...", comment: "Toast status shown while moving files")), for: actionKey)
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
            setProgress(.success(String(format: String(localized: "dropzone.manager.status.moved-files-count", defaultValue: "Moved %d files", comment: "Toast status showing how many files were moved"), count)), for: actionKey)
            
            let content = UNMutableNotificationContent()
            content.title = "FrogDrop"
            content.subtitle = String(localized: "dropzone.manager.status.files-moved-success-title", defaultValue: "Files Moved Successfully", comment: "Success alert title after moving files")
            content.body = String(format: String(localized: "dropzone.manager.status.files-moved-success-message", defaultValue: "%d file(s) moved to %@.", comment: "Success alert message with file count and destination folder name"), count, "\(destFolder.lastPathComponent)")
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            if Bundle.main.bundleIdentifier != nil {
                Task { try? await UNUserNotificationCenter.current().add(request) }
            }
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.error.move-files", defaultValue: "Error", comment: "Error alert title when moving files fails")), for: actionKey)
        }
    }
    
    func airdropFiles(_ urls: [URL]) {
        let actionKey = "action_airdrop"
        setProgress(.running(String(localized: "dropzone.manager.status.airdrop.sending", defaultValue: "AirDrop...", comment: "Toast status shown while sending files via AirDrop")), for: actionKey)
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: urls)
        setProgress(.success(String(localized: "dropzone.manager.status.airdrop.sent", defaultValue: "Sent!", comment: "Toast status shown after sending via AirDrop")), for: actionKey)
    }
    
    func emailFiles(_ urls: [URL]) {
        let actionKey = "action_email"
        setProgress(.running(String(localized: "dropzone.manager.status.email.composing", defaultValue: "Email...", comment: "Toast status shown while composing email share")), for: actionKey)
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .composeEmail)
        sharingService?.perform(withItems: urls)
        setProgress(.success(String(localized: "dropzone.manager.status.email.composed", defaultValue: "Composed!", comment: "Toast status shown after email compose is prepared")), for: actionKey)
    }
    
    func uploadToImgur(_ urls: [URL]) async {
        let actionKey = "action_imgur"
        guard let url = urls.first else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-file", defaultValue: "No file", comment: "Toast status shown when no file is available for the requested action")), for: actionKey)
            return
        }
        
        setProgress(.running(String(localized: "dropzone.manager.status.uploading", defaultValue: "Uploading...", comment: "Toast status shown while uploading to external service")), for: actionKey)
        
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
                        DropzoneManager.shared.setProgress(.success(String(localized: "dropzone.manager.status.uploaded", defaultValue: "Uploaded!", comment: "Toast status shown after upload completes successfully")), for: actionKey)
                        
                        let content = UNMutableNotificationContent()
                        content.title = "FrogDrop"
                        content.subtitle = String(localized: "dropzone.manager.status.imgur-upload-successful.title", defaultValue: "Imgur Upload Successful", comment: "Success alert title shown after uploading to Imgur")
                        content.body = String(localized: "dropzone.manager.status.imgur-upload-successful.message", defaultValue: "Link copied to clipboard!", comment: "Success alert message shown after Imgur link is copied")
                        content.sound = .default
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        if Bundle.main.bundleIdentifier != nil {
                            Task { try? await UNUserNotificationCenter.current().add(request) }
                        }
                    }
                } else {
                    await MainActor.run {
                        DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.error.imgur-upload", defaultValue: "Error", comment: "Error alert title shown when Imgur upload fails")), for: actionKey)
                    }
                }
            } catch {
                print("Imgur upload error: \(error)")
                await MainActor.run {
                    DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.error.imgur-link-copy", defaultValue: "Error", comment: "Error alert title shown when copying Imgur link fails")), for: actionKey)
                }
            }
        }
    }
    
    func shortenURL(_ urls: [URL]) async {
        let actionKey = "action_shortenURL"
        guard let url = urls.first else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-url", defaultValue: "No URL", comment: "Status text shown when no URL is available for shortening")), for: actionKey)
            return
        }
        
        setProgress(.running(String(localized: "dropzone.manager.status.shortening", defaultValue: "Shortening...", comment: "Status text shown while URL shortening is in progress")), for: actionKey)
        
        if url.scheme == "http" || url.scheme == "https" {
            let originalString = url.absoluteString
            let cleanedString = ClipboardManager.shared.cleanURL(originalString)
            
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(cleanedString, forType: .string)
                HapticManager.shared.success()
                setProgress(.success(String(localized: "dropzone.manager.status.shortened", defaultValue: "Shortened!", comment: "Status text shown when URL shortening completes")), for: actionKey)
                
                let content = UNMutableNotificationContent()
                content.title = "FrogDrop"
                content.subtitle = String(localized: "dropzone.manager.status.url-shortened.title", defaultValue: "URL Shortened", comment: "Success alert title shown after URL is shortened")
                content.body = String(localized: "dropzone.manager.status.url-shortened.message", defaultValue: "Shortened URL copied to clipboard!", comment: "Success alert message shown after shortened URL is copied")
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                if Bundle.main.bundleIdentifier != nil {
                    Task { try? await UNUserNotificationCenter.current().add(request) }
                }
            }
        } else {
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(url.lastPathComponent, forType: .string)
                setProgress(.success(String(localized: "dropzone.manager.status.copied-name", defaultValue: "Copied Name", comment: "Status text shown when file name is copied")), for: actionKey)
            }
        }
    }
    
    func zipFiles(_ urls: [URL]) async {
        let actionKey = "action_zip"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-files", defaultValue: "No files", comment: "Status text shown when no files are available for zipping")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.zipping", defaultValue: "Zipping...", comment: "Status text shown while files are being zipped")), for: actionKey)
        
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
                        DropzoneManager.shared.setProgress(.success(String(localized: "dropzone.manager.status.compressed-to-downloads", defaultValue: "Compressed! → Downloads", comment: "Status text shown after zip archive is saved to Downloads")), for: actionKey)
                        NSWorkspace.shared.activateFileViewerSelecting([zipURL])
                    } else {
                        DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.error.zip-files", defaultValue: "Error", comment: "Error alert title shown when zipping files fails")), for: actionKey)
                    }
                }
            } catch {
                print("Failed to compress files: \(error)")
                try? fileManager.removeItem(at: tempDir)
                await MainActor.run {
                    DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.error.copy-name", defaultValue: "Error", comment: "Error alert title shown when copying file name fails")), for: actionKey)
                }
            }
        }
    }
    
    func resizeImages(_ urls: [URL]) async {
        let actionKey = "action_resizeImage"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-images.resize", defaultValue: "No images", comment: "Status text shown when no images are available for resize action")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.resizing", defaultValue: "Resizing...", comment: "Status text shown while images are being resized")), for: actionKey)
        
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
                    DropzoneManager.shared.setProgress(.success(String(localized: "dropzone.manager.status.resized-to-downloads", defaultValue: "Resized → Downloads", comment: "Status text shown after resized image is saved to Downloads")), for: actionKey)
                    NSWorkspace.shared.open(downloadsDir)
                } else {
                    DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.failed.resize", defaultValue: "Failed", comment: "Status text shown when image resize action fails")), for: actionKey)
                }
            }
        }
    }
    
    func convertImagesToPNG(_ urls: [URL]) async {
        let actionKey = "action_convertImage"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-images.convert", defaultValue: "No images", comment: "Status text shown when no images are available for conversion action")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.converting.png", defaultValue: "Converting...", comment: "Status text shown while converting images to PNG")), for: actionKey)
        
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
                    DropzoneManager.shared.setProgress(.success(String(localized: "dropzone.manager.status.converted-to-downloads.png", defaultValue: "Converted → Downloads", comment: "Status text shown after PNG conversion output is saved to Downloads")), for: actionKey)
                    NSWorkspace.shared.open(downloadsDir)
                } else {
                    DropzoneManager.shared.setProgress(.failure(String(localized: "dropzone.manager.status.failed.convert-png", defaultValue: "Failed", comment: "Status text shown when PNG conversion fails")), for: actionKey)
                }
            }
        }
    }
    
    func inspectEXIF(_ urls: [URL]) async {
        let actionKey = "action_inspectEXIF"
        guard let first = urls.first else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-files.inspect-exif", defaultValue: "No files", comment: "Status text shown when no files are available for EXIF inspection")), for: actionKey)
            return
        }
        EXIFInspectorManager.shared.inspect(url: first)
        setProgress(.success(String(localized: "dropzone.manager.status.inspected-exif", defaultValue: "Inspected!", comment: "Status text shown after EXIF metadata inspection completes")), for: actionKey)
    }
    
    func extractTextOCR(_ urls: [URL]) async {
        let actionKey = "action_ocr"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-files.extract-ocr", defaultValue: "No files", comment: "Status text shown when no files are available for OCR extraction")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.extracting-ocr", defaultValue: "Extracting...", comment: "Status text shown while OCR text extraction is in progress")), for: actionKey)
        if let _ = await OCRManager.shared.extractText(from: urls) {
            setProgress(.success(String(localized: "dropzone.manager.status.copied-to-clipboard.ocr", defaultValue: "Copied to Clipboard!", comment: "Status text shown after extracted OCR text is copied to clipboard")), for: actionKey)
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-text-found", defaultValue: "No Text Found", comment: "Status text shown when OCR finds no text in the selected file")), for: actionKey)
        }
    }
    
    func convertImagesToWebP(_ urls: [URL]) async {
        let actionKey = "action_webp"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-images.convert-webp", defaultValue: "No images", comment: "Status text shown when no images are available for WebP conversion")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.converting.webp", defaultValue: "Converting...", comment: "Status text shown while converting images to WebP")), for: actionKey)
        let results = await ImageOptimizer.shared.convertToWebP(urls: urls)
        if !results.isEmpty {
            setProgress(.success(String(localized: "dropzone.manager.status.converted-to-webp", defaultValue: "Converted to WebP!", comment: "Status text shown after WebP conversion succeeds")), for: actionKey)
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.failed.convert-webp", defaultValue: "Failed", comment: "Status text shown when WebP conversion fails")), for: actionKey)
        }
    }
    
    func compressImages(_ urls: [URL]) async {
        let actionKey = "action_compress"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-images.compress", defaultValue: "No images", comment: "Status text shown when no images are available for compression")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.compressing", defaultValue: "Compressing...", comment: "Status text shown while image compression is in progress")), for: actionKey)
        let results = await ImageOptimizer.shared.compressImages(urls: urls)
        if !results.isEmpty {
            setProgress(.success(String(localized: "dropzone.manager.status.compressed", defaultValue: "Compressed!", comment: "Status text shown after image compression succeeds")), for: actionKey)
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.failed.compress", defaultValue: "Failed", comment: "Status text shown when image compression fails")), for: actionKey)
        }
    }
    
    func stripMetadata(_ urls: [URL]) async {
        let actionKey = "action_stripMetadata"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-images.strip-exif", defaultValue: "No images", comment: "Status text shown when no images are available for EXIF stripping")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.stripping-exif", defaultValue: "Stripping...", comment: "Status text shown while stripping EXIF metadata")), for: actionKey)
        let results = await ImageOptimizer.shared.stripMetadata(urls: urls)
        if !results.isEmpty {
            setProgress(.success(String(localized: "dropzone.manager.status.stripped-exif", defaultValue: "Stripped!", comment: "Status text shown after EXIF metadata is removed")), for: actionKey)
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.failed.strip-exif", defaultValue: "Failed", comment: "Status text shown when EXIF stripping fails")), for: actionKey)
        }
    }
    
    func mergePDFs(_ urls: [URL]) async {
        let actionKey = "action_mergePDF"
        guard !urls.isEmpty else {
            setProgress(.failure(String(localized: "dropzone.manager.status.no-files.merge-pdf", defaultValue: "No files", comment: "Status text shown when no files are available for PDF merge")), for: actionKey)
            return
        }
        setProgress(.running(String(localized: "dropzone.manager.status.merging-pdf", defaultValue: "Merging...", comment: "Status text shown while PDF files are being merged")), for: actionKey)
        if let _ = await PDFToolkit.shared.mergePDFs(urls: urls) {
            setProgress(.success(String(localized: "dropzone.manager.status.pdfs-merged", defaultValue: "PDFs Merged!", comment: "Status text shown after PDF merge succeeds")), for: actionKey)
        } else {
            setProgress(.failure(String(localized: "dropzone.manager.status.failed.merge-pdf", defaultValue: "Failed", comment: "Status text shown when PDF merge fails")), for: actionKey)
        }
    }
    
    func pickScreenColor() async {
        let actionKey = "action_pickColor"
        setProgress(.running(String(localized: "dropzone.manager.status.picking-color", defaultValue: "Picking...", comment: "Status text shown while screen color picking is in progress")), for: actionKey)
        if let hex = await ScreenColorSampler.shared.sampleColor() {
            setProgress(.success(String(format: String(localized: "dropzone.manager.status.copied-color-hex", defaultValue: "Copied %@", comment: "Status text shown after picked color hex value is copied"), "\(hex)")), for: actionKey)
        } else {
            setProgress(.idle, for: actionKey)
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
