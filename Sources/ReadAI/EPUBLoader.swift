import AppKit
import Foundation

final class EPUBLoader {
    func load(_ url: URL) throws -> EPUBBook {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadAI-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        try unzip(url, to: workDir)

        let rootPath = try rootfilePath(in: workDir)
        let opfURL = workDir.appendingPathComponent(rootPath)
        let package = try parsePackage(opfURL)
        let baseURL = opfURL.deletingLastPathComponent()

        let chapters = try package.spine.compactMap { idref -> EPUBChapter? in
            guard let item = package.manifest[idref] else { return nil }
            let chapterURL = baseURL.appendingPathComponent(item.href)
            guard FileManager.default.fileExists(atPath: chapterURL.path) else { return nil }
            let html = try readTextFile(chapterURL)
            let text = htmlToText(html)
            return EPUBChapter(
                title: chapterTitle(html: html, fallback: item.href),
                html: html,
                text: text,
                baseURL: chapterURL.deletingLastPathComponent()
            )
        }

        guard !chapters.isEmpty else {
            throw ReadAIError("EPUB has no readable chapters.")
        }

        return EPUBBook(title: package.title, chapters: chapters)
    }

    private func unzip(_ url: URL, to directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", url.path, "-d", directory.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ReadAIError("Could not unpack EPUB.")
        }
    }

    private func rootfilePath(in directory: URL) throws -> String {
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")
        let data = try Data(contentsOf: containerURL)
        let parser = RootfileParser()
        return try parser.parse(data)
    }

    private func parsePackage(_ url: URL) throws -> EPUBPackage {
        let data = try Data(contentsOf: url)
        let parser = OPFParser()
        return try parser.parse(data)
    }

    private func readTextFile(_ url: URL) throws -> String {
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        if let text = try? String(contentsOf: url, encoding: .isoLatin1) {
            return text
        }
        return try String(contentsOf: url)
    }

    private func htmlToText(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return html
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
        return attributed.string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chapterTitle(html: String, fallback: String) -> String {
        let patterns = [
            "<title[^>]*>(.*?)</title>",
            "<h1[^>]*>(.*?)</h1>",
            "<h2[^>]*>(.*?)</h2>"
        ]

        for pattern in patterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let raw = String(html[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty { return raw }
            }
        }

        return URL(fileURLWithPath: fallback).deletingPathExtension().lastPathComponent
    }
}

private struct EPUBPackage {
    let title: String
    let manifest: [String: EPUBManifestItem]
    let spine: [String]
}

private struct EPUBManifestItem {
    let href: String
    let mediaType: String
}

private final class RootfileParser: NSObject, XMLParserDelegate {
    private var path: String?
    private var error: Error?

    func parse(_ data: Data) throws -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error { throw error }
        guard let path else { throw ReadAIError("EPUB container is missing rootfile.") }
        return path
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "rootfile", path == nil else { return }
        path = attributeDict["full-path"]
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }
}

private final class OPFParser: NSObject, XMLParserDelegate {
    private var title = ""
    private var manifest: [String: EPUBManifestItem] = [:]
    private var spine: [String] = []
    private var currentElement = ""
    private var titleBuffer = ""
    private var error: Error?

    func parse(_ data: Data) throws -> EPUBPackage {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error { throw error }
        return EPUBPackage(title: title, manifest: manifest, spine: spine)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "item",
           let id = attributeDict["id"],
           let href = attributeDict["href"],
           let mediaType = attributeDict["media-type"] {
            manifest[id] = EPUBManifestItem(href: href, mediaType: mediaType)
        }

        if elementName == "itemref", let idref = attributeDict["idref"] {
            spine.append(idref)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "dc:title" || currentElement == "title" {
            titleBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if (elementName == "dc:title" || elementName == "title"), title.isEmpty {
            title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }
}
