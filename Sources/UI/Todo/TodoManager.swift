import Foundation

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var focusedDuration: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, focusedDuration
    }
    
    init(id: UUID, title: String, isCompleted: Bool, focusedDuration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.focusedDuration = focusedDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        focusedDuration = (try? container.decode(TimeInterval.self, forKey: .focusedDuration)) ?? 0
    }
}

class TodoManager: ObservableObject {
    static let shared = TodoManager()
    
    @Published var items: [TodoItem] = [] {
        didSet {
            save()
        }
    }
    
    private init() {
        load()
    }
    
    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TodoItem(id: UUID(), title: trimmed, isCompleted: false)
        items.append(newItem)
        HapticManager.shared.click()
    }
    
    func toggle(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            HapticManager.shared.click()
        }
    }
    
    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        HapticManager.shared.click()
    }
    
    func addDuration(id: UUID, seconds: TimeInterval) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].focusedDuration += seconds
            save()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "FrogDrop.TodoList")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "FrogDrop.TodoList"),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            self.items = decoded
        }
    }
}
