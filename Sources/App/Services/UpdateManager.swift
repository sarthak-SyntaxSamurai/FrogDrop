import Foundation
import AppKit
import Combine

/// Data models for GitHub Releases API
struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

@MainActor
class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()
    
    // GitHub Repository Configuration
    private let repoOwner = "sarthak-SyntaxSamurai"
    private let repoName = "FrogDrop"
    
    // Published State
    @Published var isChecking: Bool = false
    @Published var isUpdating: Bool = false
    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var releaseURL: String = ""
    @Published var downloadURL: String = ""
    @Published var assetType: String = "" // "zip" or "dmg"
    @Published var statusMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var lastCheckDate: Date? = nil
    
    var currentVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0"
        return version.hasPrefix("v") ? version : "v\(version)"
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Version Comparison
    
    /// Compares two semantic version strings (e.g. "v2.1.0" vs "v2.0.0")
    /// Returns true if `remote` is strictly newer than `local`
    func isNewerVersion(remote: String, local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        
        let remoteComponents = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localComponents = cleanLocal.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteComponents.count, localComponents.count)
        
        for i in 0..<maxCount {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let l = i < localComponents.count ? localComponents[i] : 0
            
            if r > l { return true }
            if r < l { return false }
        }
        
        return false
    }
    
    // MARK: - Check for Updates
    
    func checkForUpdates(silent: Bool = false) {
        guard !isChecking && !isUpdating else { return }
        
        isChecking = true
        errorMessage = nil
        if !silent {
            statusMessage = "Checking GitHub for updates..."
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            isChecking = false
            errorMessage = "Invalid GitHub repository URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("FrogDrop-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isChecking = false
                self.lastCheckDate = Date()
                
                if let error = error {
                    if !silent {
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                        self.statusMessage = String(localized: "update-manager.error.offline", defaultValue: "Could not check updates (offline)", comment: "Error message shown when update check fails due to offline state")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = String(localized: "update-manager.error.invalid-server-response", defaultValue: "Invalid response from server", comment: "Error message shown when update server response is malformed")
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    self.statusMessage = String(localized: "update-manager.error.no-releases-published", defaultValue: "No releases published yet on GitHub", comment: "Error message shown when repository has no published releases")
                    return
                }
                
                if httpResponse.statusCode == 403 {
                    self.errorMessage = String(localized: "update-manager.error.github-rate-limit", defaultValue: "GitHub API rate limit reached. Please try again later.", comment: "Error message shown when GitHub API rate limit is exceeded")
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode), let data = data else {
                    self.errorMessage = String(format: String(localized: "update-manager.error.server-http-status", defaultValue: "Server error (HTTP %d)", comment: "Error message including HTTP status code when update server returns an error"), httpResponse.statusCode)
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let remoteTag = release.tagName
                    self.latestVersion = remoteTag.hasPrefix("v") ? remoteTag : "v\(remoteTag)"
                    self.releaseNotes = release.body ?? release.name ?? String(localized: "update-manager.release-notes.fallback", defaultValue: "New performance improvements and bug fixes.", comment: "Fallback release notes text when no release body is available")
                    self.releaseURL = release.htmlUrl
                    
                    // Identify best download asset (Prefer FrogDrop.zip, fallback to FrogDrop.dmg)
                    if let zipAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) {
                        self.downloadURL = zipAsset.browserDownloadUrl
                        self.assetType = "zip"
                    } else if let dmgAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
                        self.downloadURL = dmgAsset.browserDownloadUrl
                        self.assetType = "dmg"
                    } else {
                        // Fallback release page if no direct bundle asset
                        self.downloadURL = release.htmlUrl
                        self.assetType = "web"
                    }
                    
                    if self.isNewerVersion(remote: self.latestVersion, local: self.currentVersion) {
                        self.updateAvailable = true
                        self.statusMessage = String(format: String(localized: "update-manager.status.update-available", defaultValue: "%@ is available!", comment: "Status text shown when a newer version is available"), "\(self.latestVersion)")
                        HapticManager.shared.success()
                    } else {
                        self.updateAvailable = false
                        self.statusMessage = String(format: String(localized: "update-manager.status.up-to-date", defaultValue: "FrogDrop is up to date (%@)", comment: "Status text shown when app is already on the latest version"), "\(self.currentVersion)")
                    }
                } catch {
                    self.errorMessage = String(localized: "update-manager.error.parse-release-info", defaultValue: "Failed to parse release information", comment: "Error message shown when release metadata cannot be decoded")
                    print("[UpdateManager] JSON decode error: \(error)")
                }
            }
        }.resume()
    }
    
    // MARK: - In-Place Download & Relaunch
    
    func downloadAndInstallUpdate() {
        guard !downloadURL.isEmpty else {
            if !releaseURL.isEmpty, let url = URL(string: releaseURL) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        // If web fallback
        if assetType == "web" {
            if let url = URL(string: downloadURL) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        guard let url = URL(string: downloadURL) else { return }
        
        isUpdating = true
        statusMessage = String(format: String(localized: "update-manager.progress.downloading-version", defaultValue: "Downloading %@...", comment: "Progress message while downloading update for a specific version"), "\(latestVersion)")
        errorMessage = nil
        downloadProgress = 0.05
        
        let session = URLSession(configuration: .default)
        let task = session.downloadTask(with: url) { [weak self] tempLocalURL, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.isUpdating = false
                    self.errorMessage = String(format: String(localized: "update-manager.error.download-failed-with-reason", defaultValue: "Download failed: %@", comment: "Error message with underlying reason when update download fails"), "\(error.localizedDescription)")
                    self.statusMessage = String(localized: "update-manager.error.update-failed.download", defaultValue: "Update failed", comment: "Title text shown when update download process fails")
                    return
                }
                
                guard let tempLocalURL = tempLocalURL else {
                    self.isUpdating = false
                    self.errorMessage = String(localized: "update-manager.error.downloaded-file-missing", defaultValue: "Downloaded file not found", comment: "Error message shown when expected downloaded update file is missing")
                    return
                }
                
                self.statusMessage = String(localized: "update-manager.progress.installing-and-restarting", defaultValue: "Installing update & restarting...", comment: "Progress message while installing update and restarting app")
                self.downloadProgress = 0.9
                
                self.performInPlaceUpdate(downloadedTempURL: tempLocalURL, assetType: self.assetType)
            }
        }
        
        task.resume()
    }
    
    /// Performs in-place swap and relaunch without creating duplicate apps
    private func performInPlaceUpdate(downloadedTempURL: URL, assetType: String) {
        let fileManager = FileManager.default
        let updateDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FrogDrop_InPlaceUpdate_\(UUID().uuidString)")
        
        do {
            try fileManager.createDirectory(at: updateDir, withIntermediateDirectories: true)
            let downloadedFile = updateDir.appendingPathComponent("update_archive.\(assetType)")
            
            // Move downloaded file to known staging path
            if fileManager.fileExists(atPath: downloadedFile.path) {
                try fileManager.removeItem(at: downloadedFile)
            }
            try fileManager.moveItem(at: downloadedTempURL, to: downloadedFile)
            
            // Determine target application destination
            let currentAppBundleURL = Bundle.main.bundleURL
            let targetAppPath = currentAppBundleURL.path
            
            // Generate robust helper script to unpack, swap, ad-hoc sign, and restart
            let scriptPath = updateDir.appendingPathComponent("install_and_restart.sh")
            let extractedDir = updateDir.appendingPathComponent("extracted")
            let mountDir = updateDir.appendingPathComponent("mount")
            
            var scriptContent = """
            #!/bin/bash
            sleep 0.8
            mkdir -p "\(extractedDir.path)"
            
            """
            
            if assetType == "zip" {
                scriptContent += """
                /usr/bin/ditto -xk "\(downloadedFile.path)" "\(extractedDir.path)"
                """
            } else if assetType == "dmg" {
                scriptContent += """
                mkdir -p "\(mountDir.path)"
                /usr/bin/hdiutil attach -nobrowse -readonly "\(downloadedFile.path)" -mountpoint "\(mountDir.path)"
                cp -R "\(mountDir.path)/FrogDrop.app" "\(extractedDir.path)/"
                /usr/bin/hdiutil detach "\(mountDir.path)" -force
                """
            }
            
            scriptContent += """
            
            # Find the extracted .app bundle
            APP_SOURCE=$(find "\(extractedDir.path)" -maxdepth 2 -name "FrogDrop.app" | head -n 1)
            
            if [ -d "$APP_SOURCE" ]; then
                # Remove quarantine and ad-hoc sign to prevent Gatekeeper / launch errors
                /usr/bin/xattr -dr com.apple.quarantine "$APP_SOURCE" 2>/dev/null || true
                /usr/bin/codesign --force --deep --sign - "$APP_SOURCE" 2>/dev/null || true
                
                # Replace running application bundle cleanly
                rm -rf "\(targetAppPath)"
                cp -R "$APP_SOURCE" "\(targetAppPath)"
                /usr/bin/xattr -dr com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
                /usr/bin/codesign --force --deep --sign - "\(targetAppPath)" 2>/dev/null || true
                
                # Cleanup temp directory
                rm -rf "\(updateDir.path)"
                
                # Relaunch updated single application
                /usr/bin/open -n "\(targetAppPath)"
            fi
            exit 0
            """
            
            try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            
            // Make executable
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
            
            // Execute detached script
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            try process.run()
            
            // Quit current application so replacement and restart are atomic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
            
        } catch {
            isUpdating = false
            errorMessage = String(format: String(localized: "update-manager.error.installation-with-reason", defaultValue: "Installation error: %@", comment: "Error message with underlying reason when update installation fails"), "\(error.localizedDescription)")
            statusMessage = String(localized: "update-manager.error.update-failed.installation", defaultValue: "Update failed", comment: "Title text shown when update installation process fails")
            print("[UpdateManager] In-place update failed: \(error)")
        }
    }
}
