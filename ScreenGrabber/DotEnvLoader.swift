//
//  DotEnvLoader.swift
//  ScreenGrabber
//
//  Loads a .env file into the process environment for DEBUG builds only.
//  In RELEASE builds this file is a complete no-op — no .env is ever read.
//
//  USAGE:
//    Call DotEnvLoader.load() once at app launch (see AppDelegate.applicationDidFinishLaunching).
//    After loading, keys are available via ProcessInfo.processInfo.environment["KEY"].
//
//  SECURITY:
//    .env files are excluded from git via .gitignore.
//    This file itself produces no code in Release targets.
//

import Foundation

#if DEBUG
enum DotEnvLoader {

    /// Call once at app launch. Searches common locations for a .env file and
    /// loads any KEY=VALUE pairs into the process environment.
    static func load() {
        for url in candidateURLs() {
            if loadFile(at: url) {
                CaptureLogger.log(.debug, "DotEnvLoader: loaded \(url.path)", level: .debug)
                return
            }
        }
        CaptureLogger.log(.debug, "DotEnvLoader: no .env found — using Keychain / hardcoded config", level: .debug)
    }

    // MARK: - Candidate Paths

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        // 1. SRCROOT environment variable (set by Xcode during builds)
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            urls.append(URL(fileURLWithPath: srcRoot).appendingPathComponent(".env"))
        }

        // 2. Hard-coded developer project path (fallback for direct binary runs)
        let devPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/Xcode/ScreenGrabber/.env")
        urls.append(devPath)

        // 3. Same directory as the running executable
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        urls.append(exeDir.appendingPathComponent(".env"))

        return urls
    }

    // MARK: - Parser

    @discardableResult
    private static func loadFile(at url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            guard !key.isEmpty else { continue }
            setenv(key, value, 1)
        }
        return true
    }
}
#else
enum DotEnvLoader {
    /// No-op in Release builds.
    static func load() {}
}
#endif
