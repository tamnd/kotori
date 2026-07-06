import os

/// One logger per area, all under the app subsystem.
public enum Log {
    public static let wire = Logger(subsystem: "dev.liteio.kotori", category: "wire")
    public static let cache = Logger(subsystem: "dev.liteio.kotori", category: "cache")
    public static let ui = Logger(subsystem: "dev.liteio.kotori", category: "ui")
}
