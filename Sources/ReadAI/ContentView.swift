import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ReaderPane()
                .frame(minWidth: model.readerFullscreen ? 900 : 620)

            if !model.readerFullscreen {
                Divider()

                ChatPane()
                    .frame(width: 360)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.showOpenPanel()
                } label: {
                    Label("Open", systemImage: "book")
                }
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.message))
        }
    }
}

private struct ReaderPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let book = model.activeBook {
                titleBar(book)

                switch book.content {
                case .pdf(let pdf):
                    PDFReaderView(document: pdf.document)
                case .epub(let epub):
                    EPUBReaderContainer(epub: epub)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Button {
                        model.showOpenPanel()
                    } label: {
                        Label("Open PDF or EPUB", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if let message = model.loadingMessage {
                ProgressView(message)
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func titleBar(_ book: Book) -> some View {
        HStack(spacing: 12) {
            Text(book.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Text(book.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                model.readerFullscreen.toggle()
            } label: {
                Label(
                    model.readerFullscreen ? "Exit Full" : "Full",
                    systemImage: model.readerFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct EPUBReaderContainer: View {
    @EnvironmentObject private var model: AppModel
    let epub: EPUBBook

    var body: some View {
        VStack(spacing: 0) {
            Picker("Chapter", selection: $model.selectedEPUBChapterID) {
                ForEach(epub.chapters) { chapter in
                    Text(chapter.title).tag(Optional(chapter.id))
                }
            }
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()

            if let chapter = model.selectedEPUBChapter {
                EPUBReaderView(chapter: chapter)
            } else {
                Text("No readable chapters.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ChatPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI")
                    .font(.headline)
                Spacer()
                if model.isAnswering {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(model.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(14)
                }
                .onChange(of: model.messages) { _, messages in
                    guard let id = messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            Divider()

            VStack(spacing: 10) {
                TextEditor(text: $model.draftQuestion)
                    .font(.body)
                    .frame(minHeight: 82, maxHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Button {
                        Task { await model.askAI() }
                    } label: {
                        Label("Ask", systemImage: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isAnswering)
                }
            }
            .padding(14)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "You" : "AI")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.text)
                .textSelection(.enabled)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var backgroundColor: Color {
        message.role == .user
            ? Color.accentColor.opacity(0.14)
            : Color(nsColor: .textBackgroundColor)
    }
}
