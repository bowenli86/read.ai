import AppKit
import Foundation
import PDFKit

final class ReadAIWindow: NSWindow {
    var keyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}

final class AppKitRuntime: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let defaults = UserDefaults.standard
    private let keyService = "ReadAI"
    private let keyAccount = "OpenAIAPIKey"

    private var window: ReadAIWindow!
    private var splitView = NSSplitView()
    private var libraryPane = NSView()
    private var readerPane = NSView()
    private var aiPane = NSView()
    private var tableView = NSTableView()
    private var readerHost = NSView()
    private var titleLabel = NSTextField(labelWithString: "ReadAI")
    private var pageLabel = NSTextField(labelWithString: "")
    private var progressSlider = NSSlider(value: 1, minValue: 1, maxValue: 1, target: nil, action: nil)
    private var searchField = NSSearchField()
    private var chatView = NSTextView()
    private var inputView = NSTextView()

    private var books: [Book] = []
    private var activeBook: Book?
    private var activePage = 1
    private var readingStyle = "page"
    private var fontSize: CGFloat = 18
    private var lineSpacing: CGFloat = 8
    private var theme = "dark"
    private var libraryHidden = false
    private var aiHidden = false

    static func main() {
        let app = NSApplication.shared
        let delegate = AppKitRuntime()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.finishLaunching()
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        loadSettings()
        loadLibrary()
        openStartupBookIfNeeded()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        filenames.map { URL(fileURLWithPath: $0) }.forEach(addBook)
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildWindow() {
        window = ReadAIWindow(
            contentRect: NSRect(x: 120, y: 80, width: 1380, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ReadAI"
        window.minSize = NSSize(width: 1080, height: 720)
        window.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = splitView

        libraryPane = makeLibraryPane()
        readerPane = makeReaderPane()
        aiPane = makeAIPane()
        splitView.addArrangedSubview(libraryPane)
        splitView.addArrangedSubview(readerPane)
        splitView.addArrangedSubview(aiPane)
        libraryPane.widthAnchor.constraint(equalToConstant: 240).isActive = true
        aiPane.widthAnchor.constraint(equalToConstant: 360).isActive = true

        window.makeKeyAndOrderFront(nil)
    }

    private func makeLibraryPane() -> NSView {
        let header = horizontal()
        let title = NSTextField(labelWithString: "Library")
        title.font = .boldSystemFont(ofSize: 15)
        let add = button("Add", action: #selector(addBookTapped))
        header.addArrangedSubview(title)
        header.addArrangedSubview(spacer())
        header.addArrangedSubview(add)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("books"))
        column.title = "Books"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(openSelectedBook)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = tableView

        return verticalContainer([header, scroll], insets: NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 10))
    }

    private func makeReaderPane() -> NSView {
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.lineBreakMode = .byTruncatingTail

        searchField.placeholderString = "Search"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let toolbar = horizontal()
        toolbar.addArrangedSubview(button("Library", action: #selector(toggleLibrary)))
        toolbar.addArrangedSubview(titleLabel)
        toolbar.addArrangedSubview(spacer())
        toolbar.addArrangedSubview(searchField)
        toolbar.addArrangedSubview(button("Page", action: #selector(usePageMode)))
        toolbar.addArrangedSubview(button("Scroll", action: #selector(useScrollMode)))
        toolbar.addArrangedSubview(button("Aa", action: #selector(showTypography)))
        toolbar.addArrangedSubview(button("询问AI", action: #selector(askSelectedText)))
        toolbar.addArrangedSubview(button("Full", action: #selector(toggleReaderFullscreen)))

        readerHost.wantsLayer = true
        readerHost.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let footer = horizontal()
        footer.addArrangedSubview(button("Prev", action: #selector(previousPage)))
        progressSlider.target = self
        progressSlider.action = #selector(progressChanged)
        progressSlider.controlSize = .small
        progressSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        footer.addArrangedSubview(progressSlider)
        footer.addArrangedSubview(spacer())
        footer.addArrangedSubview(pageLabel)
        footer.addArrangedSubview(spacer())
        footer.addArrangedSubview(button("Next", action: #selector(nextPage)))

        return verticalContainer([toolbar, readerHost, footer], insets: NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14))
    }

    private func makeAIPane() -> NSView {
        let header = horizontal()
        let title = NSTextField(labelWithString: "AI")
        title.font = .boldSystemFont(ofSize: 15)
        header.addArrangedSubview(title)
        header.addArrangedSubview(spacer())
        header.addArrangedSubview(button("Float", action: #selector(toggleAI)))
        header.addArrangedSubview(button("Key", action: #selector(showKeySettings)))

        chatView.isEditable = false
        chatView.font = .systemFont(ofSize: 14)
        let chatScroll = NSScrollView()
        chatScroll.hasVerticalScroller = true
        chatScroll.documentView = chatView

        let quick = horizontal()
        quick.addArrangedSubview(button("总结本章", action: #selector(summarizeChapter)))
        quick.addArrangedSubview(button("总结本段", action: #selector(summarizeSelection)))
        quick.addArrangedSubview(spacer())

        inputView.font = .systemFont(ofSize: 14)
        inputView.minSize = NSSize(width: 0, height: 70)
        let inputScroll = NSScrollView()
        inputScroll.hasVerticalScroller = true
        inputScroll.documentView = inputView
        inputScroll.heightAnchor.constraint(equalToConstant: 86).isActive = true

        let footer = horizontal()
        footer.addArrangedSubview(spacer())
        footer.addArrangedSubview(button("Paste", action: #selector(pasteIntoQuestion)))
        footer.addArrangedSubview(button("Ask", action: #selector(askQuestion)))

        return verticalContainer([header, chatScroll, quick, inputScroll, footer], insets: NSEdgeInsets(top: 14, left: 12, bottom: 12, right: 12))
    }

    private func loadSettings() {
        fontSize = CGFloat(defaults.double(forKey: "fontSize") == 0 ? 18 : defaults.double(forKey: "fontSize"))
        lineSpacing = CGFloat(defaults.double(forKey: "lineSpacing") == 0 ? 8 : defaults.double(forKey: "lineSpacing"))
        readingStyle = defaults.string(forKey: "readingStyle") ?? "page"
        theme = defaults.string(forKey: "theme") ?? "dark"
        applyTheme()
    }

    private func loadLibrary() {
        let paths = defaults.stringArray(forKey: "libraryPaths") ?? []
        books = paths.compactMap { try? loadBook(URL(fileURLWithPath: $0)) }
        tableView.reloadData()
        if let last = defaults.string(forKey: "lastOpenedBook"),
           let book = books.first(where: { $0.url.path == last }) {
            setActiveBook(book)
        }
    }

    private func openStartupBookIfNeeded() {
        let paths = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
        for path in paths where FileManager.default.fileExists(atPath: path) {
            addBook(URL(fileURLWithPath: path))
        }
    }

    private func addBook(_ url: URL) {
        guard ["pdf", "epub"].contains(url.pathExtension.lowercased()) else { return }
        do {
            let book = try loadBook(url)
            if !books.contains(where: { $0.url.path == url.path }) {
                books.append(book)
                saveLibrary()
            }
            tableView.reloadData()
            setActiveBook(book)
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func loadBook(_ url: URL) throws -> Book {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url) else { throw ReadAIError("Could not read PDF.") }
            return Book(title: url.deletingPathExtension().lastPathComponent, url: url, content: .pdf(PDFBook(document: document, text: document.string ?? "")))
        case "epub":
            let epub = try EPUBLoader().load(url)
            return Book(title: epub.title.isEmpty ? url.deletingPathExtension().lastPathComponent : epub.title, url: url, content: .epub(epub))
        default:
            throw ReadAIError("Unsupported file.")
        }
    }

    private func saveLibrary() {
        defaults.set(books.map(\.url.path), forKey: "libraryPaths")
    }

    private func setActiveBook(_ book: Book) {
        activeBook = book
        activePage = max(1, defaults.integer(forKey: positionKey(book.url)))
        defaults.set(book.url.path, forKey: "lastOpenedBook")
        titleLabel.stringValue = book.title
        window.title = "ReadAI - \(book.title)"
        renderBook()
    }

    private func renderBook() {
        readerHost.subviews.forEach { $0.removeFromSuperview() }
        guard let book = activeBook else {
            let empty = NSTextField(labelWithString: "Add a PDF or EPUB to start reading.")
            empty.font = .systemFont(ofSize: 18)
            pin(empty, to: readerHost, inset: 24)
            pageLabel.stringValue = ""
            return
        }

        switch book.content {
        case .pdf(let pdf):
            let pdfView = PDFView()
            pdfView.document = pdf.document
            pdfView.autoScales = true
            pdfView.displayMode = readingStyle == "scroll" ? .singlePageContinuous : .singlePage
            pdfView.displaysPageBreaks = true
            if let page = pdf.document.page(at: max(0, activePage - 1)) {
                pdfView.go(to: page)
            }
            pin(pdfView, to: readerHost, inset: 0)
            pageLabel.stringValue = "Page \(activePage) / \(max(1, pdf.document.pageCount))"
        case .epub(let epub):
            let textView = NSTextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.textStorage?.setAttributedString(readingStyle == "page" ? epubPageAttributedText(epub) : epubAttributedText(epub))
            textView.textContainerInset = NSSize(width: 36, height: 28)
            textView.backgroundColor = readerBackground()
            textView.textColor = readerForeground()
            textView.menu = selectionMenu()

            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.documentView = textView
            pin(scroll, to: readerHost, inset: 0)
            pageLabel.stringValue = "Page \(activePage) / \(epubPageCount(epub))"
        }
        savePosition()
        progressSlider.minValue = 1
        progressSlider.maxValue = Double(pageCount())
        progressSlider.doubleValue = Double(activePage)
    }

    private func epubAttributedText(_ epub: EPUBBook) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for chapter in epub.chapters {
            output.append(NSAttributedString(
                string: "\(chapter.title)\n",
                attributes: [.font: NSFont.boldSystemFont(ofSize: fontSize + 8), .foregroundColor: readerForeground()]
            ))
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            paragraph.paragraphSpacing = lineSpacing + 8
            output.append(NSAttributedString(
                string: "\(chapter.text)\n\n",
                attributes: [.font: NSFont.systemFont(ofSize: fontSize), .paragraphStyle: paragraph, .foregroundColor: readerForeground()]
            ))
        }
        return output
    }

    private func epubPageAttributedText(_ epub: EPUBBook) -> NSAttributedString {
        let text = epubPageText(epub)
        let output = NSMutableAttributedString()
        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        if let first = lines.first, !first.isEmpty {
            output.append(NSAttributedString(
                string: "\(first)\n\n",
                attributes: [.font: NSFont.boldSystemFont(ofSize: fontSize + 8), .foregroundColor: readerForeground()]
            ))
        }
        if lines.count > 1 {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            paragraph.paragraphSpacing = lineSpacing + 8
            output.append(NSAttributedString(
                string: String(lines[1]),
                attributes: [.font: NSFont.systemFont(ofSize: fontSize), .paragraphStyle: paragraph, .foregroundColor: readerForeground()]
            ))
        }
        return output
    }

    private func epubPageText(_ epub: EPUBBook) -> String {
        let text = epub.chapters.map { "\($0.title)\n\n\($0.text)" }.joined(separator: "\n\n")
        let size = max(900, Int(1100 - (fontSize - 18) * 22 - lineSpacing * 12))
        let start = min(text.count, (activePage - 1) * size)
        let end = min(text.count, start + size)
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        return String(text[startIndex..<endIndex])
    }

    private func epubPageCount(_ epub: EPUBBook) -> Int {
        let textCount = epub.chapters.reduce(0) { $0 + $1.text.count + $1.title.count + 4 }
        let size = max(900, Int(1100 - (fontSize - 18) * 22 - lineSpacing * 12))
        return max(1, Int(ceil(Double(textCount) / Double(size))))
    }

    private func pageCount() -> Int {
        guard let book = activeBook else { return 1 }
        switch book.content {
        case .pdf(let pdf): return max(1, pdf.document.pageCount)
        case .epub(let epub): return epubPageCount(epub)
        }
    }

    private func selectedText() -> String {
        guard let textView = findTextView(in: readerHost), textView.selectedRange().length > 0 else {
            if let pdfView = findPDFView(in: readerHost) {
                return pdfView.currentSelection?.string ?? ""
            }
            return ""
        }
        return (textView.string as NSString).substring(with: textView.selectedRange())
    }

    private func contextText() -> String {
        if let selected = Optional(selectedText()), !selected.isEmpty { return selected }
        guard let book = activeBook else { return "" }
        switch book.content {
        case .pdf(let pdf):
            return String(pdf.text.prefix(4000))
        case .epub(let epub):
            return String(epub.chapters.map(\.text).joined(separator: "\n\n").prefix(4000))
        }
    }

    private func savePosition() {
        guard let book = activeBook else { return }
        defaults.set(activePage, forKey: positionKey(book.url))
    }

    private func positionKey(_ url: URL) -> String {
        "position:\(url.path)"
    }

    private func applyTheme() {
        window?.contentView?.appearance = theme == "dark" ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
    }

    private func readerBackground() -> NSColor {
        switch theme {
        case "light": return .textBackgroundColor
        case "sepia": return NSColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)
        default: return NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        }
    }

    private func readerForeground() -> NSColor {
        theme == "dark" ? .white : .labelColor
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123, 51:
            previousPage()
            return true
        case 124, 49:
            nextPage()
            return true
        default:
            return false
        }
    }

    @objc private func addBookTapped() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["pdf", "epub"]
        if panel.runModal() == .OK {
            panel.urls.forEach(addBook)
        }
    }

    @objc private func openSelectedBook() {
        let row = tableView.selectedRow
        guard row >= 0, row < books.count else { return }
        setActiveBook(books[row])
    }

    @objc private func previousPage() {
        activePage = max(1, activePage - 1)
        renderBook()
    }

    @objc private func nextPage() {
        activePage = min(pageCount(), activePage + 1)
        renderBook()
    }

    @objc private func progressChanged() {
        activePage = min(pageCount(), max(1, Int(progressSlider.doubleValue.rounded())))
        renderBook()
    }

    @objc private func usePageMode() {
        readingStyle = "page"
        defaults.set(readingStyle, forKey: "readingStyle")
        renderBook()
    }

    @objc private func useScrollMode() {
        readingStyle = "scroll"
        defaults.set(readingStyle, forKey: "readingStyle")
        renderBook()
    }

    @objc private func toggleLibrary() {
        libraryHidden.toggle()
        libraryPane.isHidden = libraryHidden
    }

    @objc private func toggleAI() {
        aiHidden.toggle()
        aiPane.isHidden = aiHidden
    }

    @objc private func toggleReaderFullscreen() {
        libraryHidden = true
        aiHidden = true
        libraryPane.isHidden = true
        aiPane.isHidden = true
        window.toggleFullScreen(nil)
    }

    @objc private func showTypography(_ sender: NSButton) {
        let popover = NSPopover()
        let stack = vertical(spacing: 10)
        stack.addArrangedSubview(label("Font Size"))
        let fontSlider = NSSlider(value: Double(fontSize), minValue: 12, maxValue: 30, target: self, action: #selector(fontSizeChanged(_:)))
        stack.addArrangedSubview(fontSlider)
        stack.addArrangedSubview(label("Line Spacing"))
        let lineSlider = NSSlider(value: Double(lineSpacing), minValue: 0, maxValue: 24, target: self, action: #selector(lineSpacingChanged(_:)))
        stack.addArrangedSubview(lineSlider)
        let themeRow = horizontal()
        themeRow.addArrangedSubview(button("Dark", action: #selector(useDarkTheme)))
        themeRow.addArrangedSubview(button("Light", action: #selector(useLightTheme)))
        themeRow.addArrangedSubview(button("Sepia", action: #selector(useSepiaTheme)))
        stack.addArrangedSubview(themeRow)
        let controller = NSViewController()
        controller.view = padded(stack, width: 240, height: 150)
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        fontSize = CGFloat(sender.doubleValue)
        defaults.set(Double(fontSize), forKey: "fontSize")
        renderBook()
    }

    @objc private func lineSpacingChanged(_ sender: NSSlider) {
        lineSpacing = CGFloat(sender.doubleValue)
        defaults.set(Double(lineSpacing), forKey: "lineSpacing")
        renderBook()
    }

    @objc private func useDarkTheme() { setTheme("dark") }
    @objc private func useLightTheme() { setTheme("light") }
    @objc private func useSepiaTheme() { setTheme("sepia") }

    private func setTheme(_ value: String) {
        theme = value
        defaults.set(value, forKey: "theme")
        applyTheme()
        renderBook()
    }

    @objc private func searchChanged() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if let textView = findTextView(in: readerHost),
           let range = textView.string.range(of: query, options: [.caseInsensitive]) {
            let nsRange = NSRange(range, in: textView.string)
            textView.setSelectedRange(nsRange)
            textView.scrollRangeToVisible(nsRange)
        } else if let pdfView = findPDFView(in: readerHost),
                  let selections = pdfView.document?.findString(query, withOptions: .caseInsensitive),
                  let first = selections.first {
            pdfView.setCurrentSelection(first, animate: true)
            pdfView.go(to: first)
        }
    }

    @objc private func askSelectedText() {
        let text = selectedText()
        guard !text.isEmpty else { return }
        submit("请总结这段文字：\n\(text)", context: text)
    }

    @objc private func summarizeChapter() {
        submit("总结本章内容", context: contextText())
    }

    @objc private func summarizeSelection() {
        askSelectedText()
    }

    @objc private func pasteIntoQuestion() {
        inputView.string += NSPasteboard.general.string(forType: .string) ?? ""
    }

    @objc private func askQuestion() {
        let question = inputView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        inputView.string = ""
        submit(question, context: contextText())
    }

    private func submit(_ question: String, context: String) {
        appendChat("You", question)
        let apiKey = KeychainStore.load(service: keyService, account: keyAccount) ?? ""
        guard !apiKey.isEmpty else {
            appendChat("AI", "Set your API key first.")
            return
        }
        let client = AIClient(
            apiKey: apiKey,
            baseURL: defaults.string(forKey: "baseURL") ?? "https://api.openai.com/v1",
            model: defaults.string(forKey: "modelName") ?? "gpt-4.1-mini"
        )
        Task {
            do {
                let answer = try await client.answer(question: question, context: context)
                await MainActor.run { self.appendChat("AI", answer) }
            } catch {
                await MainActor.run { self.appendChat("AI", error.localizedDescription) }
            }
        }
    }

    private func appendChat(_ role: String, _ text: String) {
        chatView.string += "\(role): \(text)\n\n"
        chatView.scrollToEndOfDocument(nil)
    }

    @objc private func showKeySettings() {
        let alert = NSAlert()
        alert.messageText = "AI Settings"
        let stack = vertical(spacing: 8)
        let key = NSSecureTextField(string: KeychainStore.load(service: keyService, account: keyAccount) ?? "")
        key.placeholderString = "OpenAI API Key"
        let base = NSTextField(string: defaults.string(forKey: "baseURL") ?? "https://api.openai.com/v1")
        let model = NSTextField(string: defaults.string(forKey: "modelName") ?? "gpt-4.1-mini")
        stack.addArrangedSubview(label("API Key"))
        stack.addArrangedSubview(key)
        stack.addArrangedSubview(label("Base URL"))
        stack.addArrangedSubview(base)
        stack.addArrangedSubview(label("Model"))
        stack.addArrangedSubview(model)
        alert.accessoryView = padded(stack, width: 420, height: 160)
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            KeychainStore.save(key.stringValue, service: keyService, account: keyAccount)
            defaults.set(base.stringValue, forKey: "baseURL")
            defaults.set(model.stringValue, forKey: "modelName")
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        books.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let title = NSTextField(labelWithString: books[row].title)
        title.lineBreakMode = .byTruncatingTail
        pin(title, to: cell, inset: 4)
        cell.textField = title
        return cell
    }

    private func selectionMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "询问AI", action: #selector(askSelectedText), keyEquivalent: "")
        return menu
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
    }

    private func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView { return textView }
        return view.subviews.compactMap(findTextView).first
    }

    private func findPDFView(in view: NSView) -> PDFView? {
        if let pdfView = view as? PDFView { return pdfView }
        return view.subviews.compactMap(findPDFView).first
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private func horizontal(spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }

    private func vertical(spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func verticalContainer(_ views: [NSView], insets: NSEdgeInsets) -> NSView {
        let view = NSView()
        let stack = vertical(spacing: 10)
        stack.alignment = .width
        views.forEach(stack.addArrangedSubview)
        pin(stack, to: view, insets: insets)
        return view
    }

    private func padded(_ view: NSView, width: CGFloat, height: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        pin(view, to: container, inset: 12)
        return container
    }

    private func pin(_ child: NSView, to parent: NSView, inset: CGFloat) {
        pin(child, to: parent, insets: NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    }

    private func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom)
        ])
    }
}
