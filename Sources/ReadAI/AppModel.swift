import AppKit
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var activeBook: Book?
    @Published var selectedEPUBChapterID: UUID?
    @Published var messages: [ChatMessage] = []
    @Published var draftQuestion = ""
    @Published var isAnswering = false
    @Published var loadingMessage: String?
    @Published var alert: AppAlert?
    @Published var readerFullscreen = false

    @AppStorage("ai.baseURL") var baseURL = "https://api.openai.com/v1"
    @AppStorage("ai.model") var modelName = "gpt-4.1-mini"

    private let epubLoader = EPUBLoader()
    private var didOpenStartupBook = false
    private var openFileObserver: NSObjectProtocol?

    init() {
        openFileObserver = NotificationCenter.default.addObserver(
            forName: .readAIOpenFile,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            Task { @MainActor [weak self] in
                await self?.openBook(url)
            }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.openStartupBookIfNeeded()
        }
    }

    var apiKey: String {
        get { KeychainStore.load(service: "ReadAI", account: "openai-api-key") ?? "" }
        set {
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                KeychainStore.delete(service: "ReadAI", account: "openai-api-key")
            } else {
                KeychainStore.save(newValue, service: "ReadAI", account: "openai-api-key")
            }
        }
    }

    var selectedEPUBChapter: EPUBChapter? {
        guard case .epub(let epub) = activeBook?.content else { return nil }
        return epub.chapters.first { $0.id == selectedEPUBChapterID } ?? epub.chapters.first
    }

    var currentContext: String {
        switch activeBook?.content {
        case .pdf(let document):
            return String(document.text.prefix(8_000))
        case .epub:
            return String((selectedEPUBChapter?.text ?? "").prefix(8_000))
        case .none:
            return ""
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, UTType(filenameExtension: "epub") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.openBook(url)
            }
        }
    }

    func openStartupBookIfNeeded() async {
        guard !didOpenStartupBook else { return }
        didOpenStartupBook = true

        guard let path = E2EOptions.current.startupBookPath,
              FileManager.default.fileExists(atPath: path) else {
            return
        }
        await openBook(URL(fileURLWithPath: path))
    }

    func openBook(_ url: URL) async {
        loadingMessage = "Opening..."
        defer { loadingMessage = nil }

        do {
            switch url.pathExtension.lowercased() {
            case "pdf":
                guard let pdf = PDFDocument(url: url) else {
                    throw ReadAIError("Could not read PDF.")
                }
                let text = pdf.string ?? ""
                activeBook = Book(
                    title: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    content: .pdf(PDFBook(document: pdf, text: text))
                )
            case "epub":
                let epub = try epubLoader.load(url)
                activeBook = Book(
                    title: epub.title.isEmpty ? url.deletingPathExtension().lastPathComponent : epub.title,
                    url: url,
                    content: .epub(epub)
                )
                selectedEPUBChapterID = epub.chapters.first?.id
            default:
                throw ReadAIError("Unsupported file.")
            }
            messages.removeAll()
            writeE2EStatus(for: url)
        } catch {
            alert = AppAlert(message: error.localizedDescription)
            writeE2EStatus(for: url, error: error)
        }
    }

    func askAI() async {
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return }

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            alert = AppAlert(message: "Add an API key in Settings.")
            return
        }

        draftQuestion = ""
        messages.append(ChatMessage(role: .user, text: question))
        isAnswering = true
        defer { isAnswering = false }

        do {
            let client = AIClient(apiKey: key, baseURL: baseURL, model: modelName)
            let answer = try await client.answer(question: question, context: currentContext)
            messages.append(ChatMessage(role: .assistant, text: answer))
        } catch {
            messages.append(ChatMessage(role: .assistant, text: error.localizedDescription))
        }
    }

    private func writeE2EStatus(for url: URL, error: Error? = nil) {
        guard let path = E2EOptions.current.statusPath else { return }

        let payload: [String: Any]
        if let error {
            payload = [
                "ok": false,
                "path": url.path,
                "error": error.localizedDescription
            ]
        } else {
            payload = [
                "ok": true,
                "path": url.path,
                "title": activeBook?.title ?? "",
                "kind": activeBook?.kind ?? "",
                "textLength": currentContext.count,
                "chapterCount": activeBook?.chapterCount ?? 0
            ]
        }

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }

        if E2EOptions.current.exitAfterOpen {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                NSApp.terminate(nil)
            }
        }
    }
}
