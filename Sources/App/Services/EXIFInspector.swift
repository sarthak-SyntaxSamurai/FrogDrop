import AppKit
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - EXIF Report Model
struct EXIFReport: Identifiable {
    let id = UUID()
    let fileURL: URL
    let isClean: Bool
    
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    let gpsFormatted: String?
    
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let focalLength: String?
    let fNumber: String?
    let isoSpeed: String?
    let shutterSpeed: String?
    
    let dateTimeOriginal: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let colorProfile: String?
    let fileSizeString: String
}

// MARK: - EXIF Extractor Engine
enum EXIFExtractor {
    static func analyze(url: URL) -> EXIFReport {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            return EXIFReport(
                fileURL: url,
                isClean: true,
                gpsLatitude: nil,
                gpsLongitude: nil,
                gpsFormatted: nil,
                cameraMake: nil,
                cameraModel: nil,
                lensModel: nil,
                focalLength: nil,
                fNumber: nil,
                isoSpeed: nil,
                shutterSpeed: nil,
                dateTimeOriginal: nil,
                pixelWidth: nil,
                pixelHeight: nil,
                colorProfile: nil,
                fileSizeString: sizeStr
            )
        }
        
        let gpsDict = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        
        // GPS data
        var lat: Double? = nil
        var lon: Double? = nil
        var gpsFormatted: String? = nil
        
        if let gps = gpsDict {
            if let latVal = gps[kCGImagePropertyGPSLatitude] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
                lat = latRef.uppercased() == "S" ? -latVal : latVal
            }
            if let lonVal = gps[kCGImagePropertyGPSLongitude] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                lon = lonRef.uppercased() == "W" ? -lonVal : lonVal
            }
            if let lat = lat, let lon = lon {
                gpsFormatted = String(format: "%.4f°, %.4f°", lat, lon)
            }
        }
        
        // Camera & Lens
        let make = tiffDict?[kCGImagePropertyTIFFMake] as? String
        let model = tiffDict?[kCGImagePropertyTIFFModel] as? String
        let lens = exifDict?[kCGImagePropertyExifLensModel] as? String
        
        var focal: String? = nil
        if let f = exifDict?[kCGImagePropertyExifFocalLength] as? Double {
            focal = String(format: String(
                localized: "exif.inspector.focal-length.mm",
                defaultValue: "%dmm",
                comment: "Formatted focal length value in millimeters"
            ), Int(round(f)))
        }
        
        var fNumber: String? = nil
        if let fn = exifDict?[kCGImagePropertyExifFNumber] as? Double {
            fNumber = String(format: "ƒ/%.1f", fn)
        }
        
        var iso: String? = nil
        if let isoRatings = exifDict?[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = isoRatings.first {
            iso = String(format: String(
                localized: "exif.inspector.iso.value",
                defaultValue: "ISO %@",
                comment: "Formatted ISO sensitivity value"
            ), "\(first)")
        }
        
        var shutter: String? = nil
        if let expTime = exifDict?[kCGImagePropertyExifExposureTime] as? Double {
            if expTime < 1.0 && expTime > 0 {
                shutter = String(format: String(
                    localized: "exif.inspector.exposure-time.fraction-seconds",
                    defaultValue: "1/%ds",
                    comment: "Formatted exposure time as reciprocal seconds"
                ), Int(round(1.0 / expTime)))
            } else {
                shutter = String(format: "%.1fs", expTime)
            }
        }
        
        // Date & Dimensions
        let date = (exifDict?[kCGImagePropertyExifDateTimeOriginal] as? String) ?? (tiffDict?[kCGImagePropertyTIFFDateTime] as? String)
        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        let colorProfile = properties[kCGImagePropertyProfileName] as? String
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        
        let hasGPS = lat != nil && lon != nil
        let hasCameraInfo = model != nil || make != nil || lens != nil
        let isClean = !hasGPS && !hasCameraInfo
        
        return EXIFReport(
            fileURL: url,
            isClean: isClean,
            gpsLatitude: lat,
            gpsLongitude: lon,
            gpsFormatted: gpsFormatted,
            cameraMake: make,
            cameraModel: model,
            lensModel: lens,
            focalLength: focal,
            fNumber: fNumber,
            isoSpeed: iso,
            shutterSpeed: shutter,
            dateTimeOriginal: date,
            pixelWidth: width,
            pixelHeight: height,
            colorProfile: colorProfile,
            fileSizeString: sizeStr
        )
    }
}

// MARK: - SwiftUI EXIF Inspector View
struct EXIFInspectorView: View {
    let report: EXIFReport
    var onClose: () -> Void
    @State private var isStripping = false
    @State private var stripSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(
                        localized: "exif.inspector.title",
                        defaultValue: "EXIF & Privacy Inspector",
                        comment: "Title of the EXIF and privacy inspection panel"
                    ))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(report.fileURL.lastPathComponent)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    // Privacy Status Banner
                    HStack(spacing: 10) {
                        Image(systemName: report.isClean ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(report.isClean ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.isClean ? String(
                                localized: "exif.inspector.privacy-status.clean-image",
                                defaultValue: "100% Clean Image",
                                comment: "Badge text indicating image has no sensitive metadata"
                            ) : String(
                                localized: "exif.inspector.privacy-status.sensitive-detected",
                                defaultValue: "Sensitive Metadata Detected",
                                comment: "Badge text indicating sensitive metadata was found"
                            ))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(report.isClean ? .green : .orange)
                            
                            Text(report.isClean ? String(
                                localized: "exif.inspector.privacy-status.clean-description",
                                defaultValue: "No GPS location, camera serial, or sensitive tags found.",
                                comment: "Description shown when no sensitive metadata exists"
                            ) : String(
                                localized: "exif.inspector.privacy-status.sensitive-description",
                                defaultValue: "Contains location or camera information that can identify where & when it was taken.",
                                comment: "Description shown when sensitive metadata exists"
                            ))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((report.isClean ? Color.green : Color.orange).opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke((report.isClean ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                    )
                    
                    // Location Card (if GPS present)
                    if let gps = report.gpsFormatted, let lat = report.gpsLatitude, let lon = report.gpsLongitude {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(String(
                                localized: "exif.inspector.section.gps-location",
                                defaultValue: "GPS Location",
                                comment: "Section title for GPS metadata details"
                            ), systemImage: "location.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                            
                            HStack {
                                Text(gps)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    if let mapsURL = URL(string: "https://maps.apple.com/?q=\(lat),\(lon)") {
                                        NSWorkspace.shared.open(mapsURL)
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "map.fill")
                                        Text(String(
                                            localized: "exif.inspector.gps.open-maps",
                                            defaultValue: "Open Maps",
                                            comment: "Button title to open detected coordinates in Maps"
                                        ))
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    // Camera & Settings Card
                    if report.cameraModel != nil || report.cameraMake != nil || report.lensModel != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(String(
                                localized: "exif.inspector.section.camera-optics",
                                defaultValue: "Camera & Optics",
                                comment: "Section title for camera and lens metadata"
                            ), systemImage: "camera.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            
                            if let make = report.cameraMake, let model = report.cameraModel {
                                MetaRow(label: String(
                                    localized: "exif.inspector.camera.device.header",
                                    defaultValue: "Device",
                                    comment: "Header label for device metadata in camera section"
                                ), value: "\(make) \(model)")
                            } else if let model = report.cameraModel {
                                MetaRow(label: String(
                                    localized: "exif.inspector.camera.device.row-label",
                                    defaultValue: "Device",
                                    comment: "Row label for device metadata value"
                                ), value: model)
                            }
                            
                            if let lens = report.lensModel {
                                MetaRow(label: String(
                                    localized: "exif.inspector.camera.lens.row-label",
                                    defaultValue: "Lens",
                                    comment: "Row label for lens metadata value"
                                ), value: lens)
                            }
                            
                            HStack(spacing: 8) {
                                if let f = report.focalLength { MetaBadge(text: f) }
                                if let fn = report.fNumber { MetaBadge(text: fn) }
                                if let iso = report.isoSpeed { MetaBadge(text: iso) }
                                if let s = report.shutterSpeed { MetaBadge(text: s) }
                            }
                            .padding(.top, 2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    // File Details Card
                    VStack(alignment: .leading, spacing: 6) {
                        Label(String(
                            localized: "exif.inspector.section.file-resolution",
                            defaultValue: "File & Resolution",
                            comment: "Section title for file and resolution metadata"
                        ), systemImage: "doc.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        if let w = report.pixelWidth, let h = report.pixelHeight {
                            MetaRow(label: String(
                                localized: "exif.inspector.file.dimensions.label",
                                defaultValue: "Dimensions",
                                comment: "Row label for image dimensions"
                            ), value: String(format: String(
                                localized: "exif.inspector.file.dimensions.value",
                                defaultValue: "%d × %d px",
                                comment: "Formatted image dimensions in pixels"
                            ), w, h))
                        }
                        MetaRow(label: String(
                            localized: "exif.inspector.file.size.label",
                            defaultValue: "File Size",
                            comment: "Row label for file size metadata"
                        ), value: report.fileSizeString)
                        if let date = report.dateTimeOriginal {
                            MetaRow(label: String(
                                localized: "exif.inspector.file.captured.label",
                                defaultValue: "Captured",
                                comment: "Row label for capture timestamp metadata"
                            ), value: date)
                        }
                        if let profile = report.colorProfile {
                            MetaRow(label: String(
                                localized: "exif.inspector.file.color-profile.label",
                                defaultValue: "Color Profile",
                                comment: "Row label for color profile metadata"
                            ), value: profile)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                .padding(14)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Action Footer
            HStack(spacing: 10) {
                if !report.isClean {
                    Button(action: {
                        Task {
                            isStripping = true
                            _ = await ImageOptimizer.shared.stripMetadata(urls: [report.fileURL])
                            isStripping = false
                            stripSuccess = true
                            HapticManager.shared.success()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: stripSuccess ? "checkmark.circle.fill" : "shield.checkerboard")
                            Text(stripSuccess ? String(
                                localized: "exif.inspector.clean-copy-saved-downloads",
                                defaultValue: "Clean Copy Saved in Downloads!",
                                comment: "Success title after saving a cleaned image copy to Downloads."
                            ) : String(
                                localized: "exif.inspector.strip-metadata-clean",
                                defaultValue: "Strip Metadata & Clean",
                                comment: "Button title for stripping metadata and producing a clean copy."
                            ))
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(stripSuccess ? Color.green : Color.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isStripping || stripSuccess)
                }
                
                Button(action: onClose) {
                    Text(report.isClean ? String(
                        localized: "exif.inspector.action.done",
                        defaultValue: "Done",
                        comment: "Confirmation button title after finishing metadata cleanup."
                    ) : String(
                        localized: "exif.inspector.action.close",
                        defaultValue: "Close",
                        comment: "Button title to close the metadata cleanup UI."
                    ))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 320, height: 420)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct MetaRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

private struct MetaBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .foregroundColor(.primary)
            .cornerRadius(4)
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - EXIF Inspector Window Manager
@MainActor
class EXIFInspectorManager {
    static let shared = EXIFInspectorManager()
    private var window: NSPanel?
    
    private init() {}
    
    func inspect(url: URL) {
        let report = EXIFExtractor.analyze(url: url)
        
        window?.close()
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        let hostingView = NSHostingView(rootView: EXIFInspectorView(report: report, onClose: { [weak panel] in
            panel?.close()
        }))
        panel.contentView = hostingView
        panel.center()
        panel.orderFrontRegardless()
        
        self.window = panel
        HapticManager.shared.tick()
    }
}
