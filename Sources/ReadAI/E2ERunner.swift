import Darwin
import Foundation
import PDFKit

enum E2ERunner {
    static func runIfRequested() {
        let options = E2EOptions.current
        guard options.statusPath != nil else { return }

        guard let path = options.startupBookPath else {
            write(["ok": false, "error": "Missing book path."], options: options)
            exit(2)
        }

        let url = URL(fileURLWithPath: path)

        do {
            switch url.pathExtension.lowercased() {
            case "pdf":
                guard let document = PDFDocument(url: url) else {
                    throw ReadAIError("Could not read PDF.")
                }
                write([
                    "ok": true,
                    "kind": "pdf",
                    "path": url.path,
                    "title": url.deletingPathExtension().lastPathComponent,
                    "textLength": document.string?.count ?? 0,
                    "chapterCount": 0
                ], options: options)
            case "epub":
                let epub = try EPUBLoader().load(url)
                write([
                    "ok": true,
                    "kind": "epub",
                    "path": url.path,
                    "title": epub.title,
                    "textLength": epub.chapters.first?.text.count ?? 0,
                    "chapterCount": epub.chapters.count
                ], options: options)
            default:
                throw ReadAIError("Unsupported file.")
            }
            exit(0)
        } catch {
            write([
                "ok": false,
                "path": url.path,
                "error": error.localizedDescription
            ], options: options)
            exit(1)
        }
    }

    private static func write(_ payload: [String: Any], options: E2EOptions) {
        guard let path = options.statusPath,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
