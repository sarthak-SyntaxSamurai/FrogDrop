import AppKit

@main
struct FrogDropApp {
    @MainActor
    static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
