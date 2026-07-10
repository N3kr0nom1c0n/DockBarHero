import OSLog

enum AppLog {
    private static let subsystem = "com.n3kr0nom1c0n.DockBarHero"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let placement = Logger(subsystem: subsystem, category: "placement")
    static let environment = Logger(subsystem: subsystem, category: "environment")
    static let scene = Logger(subsystem: subsystem, category: "scene")
}
