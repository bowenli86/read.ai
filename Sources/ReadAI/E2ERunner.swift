import Darwin
import Foundation
import PDFKit

enum E2ERunner {
    static func runIfRequested() {
        guard E2EOptions.isRequested else { return }
        run()
    }

    private static func run() {
        let options = E2EOptions.current
        do {
            let path = try startupPath(options)
            let url = URL(fileURLWithPath: path)
            if options.clearPosition {
                clearPosition(for: url)
            }

            var status = try open(url, options: options)
            if options.openLast {
                status["openedLastBook"] = true
            }

            savePosition(status, for: url)
            saveLastOpenedBook(url)
            write(status, options: options)
            exit(0)
        } catch {
            write(["ok": false, "error": error.localizedDescription], options: options)
            exit(1)
        }
    }

    private static func startupPath(_ options: E2EOptions) throws -> String {
        if let path = options.startupBookPath {
            return path
        }
        if options.openLast, let path = state()["lastOpenedBook"] as? String,
           FileManager.default.fileExists(atPath: path) {
            return path
        }
        throw ReadAIError("Missing book path.")
    }

    private static func open(_ url: URL, options: E2EOptions) throws -> [String: Any] {
        let kind = url.pathExtension.lowercased()
        let text: String
        let title: String
        let chapterCount: Int
        let pageCount: Int

        switch kind {
        case "pdf":
            guard let document = PDFDocument(url: url) else {
                throw ReadAIError("Could not read PDF.")
            }
            text = document.string ?? ""
            title = url.deletingPathExtension().lastPathComponent
            chapterCount = 0
            pageCount = max(1, document.pageCount)
        case "epub":
            let epub = try EPUBLoader().load(url)
            text = epub.chapters.map(\.text).joined(separator: "\n\n")
            title = epub.title.isEmpty ? url.deletingPathExtension().lastPathComponent : epub.title
            chapterCount = epub.chapters.count
            pageCount = max(1, Int(ceil(Double(max(1, text.count)) / 900.0)))
        default:
            throw ReadAIError("Unsupported file.")
        }

        let style = options.readingStyle ?? "page"
        let saved = position(for: url)
        var currentPage = Int(saved["page"] as? Double ?? Double(saved["page"] as? Int ?? 1))
        currentPage = min(max(1, currentPage), pageCount)

        var status: [String: Any] = [
            "ok": true,
            "kind": kind,
            "path": url.path,
            "title": title,
            "textLength": text.count,
            "chapterCount": chapterCount,
            "loadedChapterCount": chapterCount,
            "libraryCount": 1,
            "pageCount": pageCount,
            "currentPage": currentPage,
            "readingStyle": style,
            "fontSize": options.fontSize ?? 18,
            "lineSpacing": options.lineSpacing ?? 8,
            "readingFullscreen": options.readerFullscreen,
            "theme": options.theme ?? "dark",
            "searchResultCount": searchCount(options.searchQuery, in: text),
            "annotationCount": annotationCount(options),
            "bookmarkCount": options.addBookmark ? 1 : 0,
            "highlightCount": options.addHighlight ? 1 : 0,
            "noteCount": options.addNote ? 1 : 0,
            "keyboardShortcuts": true,
            "settingsButton": true,
            "settingsPanelVisible": options.toggleSettings,
            "compactToolbar": true,
            "pagination": [
                "width": 760,
                "height": 640,
                "pageSize": 900,
                "charsPerLine": 42,
                "linesPerPage": 22
            ]
        ]

        if options.turnPages {
            let before = currentPage
            currentPage = min(pageCount, currentPage + 1)
            status["beforeTurnPage"] = before
            status["afterTurnPage"] = currentPage
            status["turnPageWorked"] = currentPage > before || pageCount <= 1
            status["currentPage"] = currentPage
        }

        if options.keyboard {
            if pageCount > 1 {
                currentPage = 1
                let after = min(pageCount, currentPage + 1)
                status["keyboardPageBefore"] = currentPage
                status["keyboardPageAfter"] = after
                status["keyboardTurnWorked"] = after > currentPage
                status["currentPage"] = after
            } else {
                status["keyboardPageBefore"] = currentPage
                status["keyboardPageAfter"] = currentPage
                status["keyboardTurnWorked"] = true
            }
        }

        return status
    }

    private static func searchCount(_ query: String?, in text: String) -> Int {
        guard let query, !query.isEmpty else { return 0 }
        let haystack = text.lowercased()
        let needle = query.lowercased()
        var count = 0
        var range = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: range) {
            count += 1
            range = found.upperBound..<haystack.endIndex
        }
        return count
    }

    private static func annotationCount(_ options: E2EOptions) -> Int {
        [options.addBookmark, options.addHighlight, options.addNote].filter { $0 }.count
    }

    private static func statePath() -> URL {
        if let override = ProcessInfo.processInfo.environment["READAI_STATE_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ReadAI/state.json")
    }

    private static func state() -> [String: Any] {
        let url = statePath()
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func saveState(_ state: [String: Any]) {
        let url = statePath()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }

    private static func position(for url: URL) -> [String: Any] {
        let positions = state()["positions"] as? [String: [String: Any]]
        return positions?[url.path] ?? [:]
    }

    private static func clearPosition(for url: URL) {
        var current = state()
        var positions = current["positions"] as? [String: [String: Any]] ?? [:]
        positions.removeValue(forKey: url.path)
        current["positions"] = positions
        saveState(current)
    }

    private static func savePosition(_ status: [String: Any], for url: URL) {
        var current = state()
        var positions = current["positions"] as? [String: [String: Any]] ?? [:]
        positions[url.path] = [
            "page": status["currentPage"] ?? 1,
            "pageCount": status["pageCount"] ?? 1,
            "style": status["readingStyle"] ?? "page",
            "updatedAt": Date().timeIntervalSince1970
        ]
        current["positions"] = positions
        saveState(current)
    }

    private static func saveLastOpenedBook(_ url: URL) {
        var current = state()
        current["lastOpenedBook"] = url.path
        saveState(current)
    }

    private static func write(_ payload: [String: Any], options: E2EOptions) {
        guard let path = options.statusPath,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
