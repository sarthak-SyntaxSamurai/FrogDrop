import Foundation

// Struct representing a customizable Dropzone item
struct DropzoneItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let type: String // "folder" or "action"
    let name: String
    var path: String? // for folders
    var actionType: String? // for actions
}
