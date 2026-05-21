import os

enum Log {
    static let general = Logger(subsystem: "dev.phosphene", category: "General")
    static let video = Logger(subsystem: "dev.phosphene", category: "Video")
    static let storage = Logger(subsystem: "dev.phosphene", category: "Storage")
    static let login = Logger(subsystem: "dev.phosphene", category: "LaunchAtLogin")
    static let update = Logger(subsystem: "dev.phosphene", category: "Update")
}
