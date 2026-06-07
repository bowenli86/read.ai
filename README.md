# ReadAI

Native macOS reading app with a hideable left library, center reading pane, and right AI chat pane.

ReadAI 是一个 macOS 原生读书应用：左侧是可隐藏书库，中间阅读 PDF/EPUB，右侧是 AI 对话区，方便边读边问。

## 中文功能

- 支持本地 PDF 阅读
- 支持本地 EPUB 阅读
- 左侧书库可隐藏/显示，减少阅读时的屏幕占用
- 支持分页阅读和向下滚动阅读
- 支持 PDF/EPUB 阅读全屏，隐藏书库和 AI 区
- 支持 EPUB 字体大小和行距调节
- 支持选中文字后点击 `询问AI` 总结该段内容
- AI 区支持连续对话，类似 GPT
- AI 快捷操作：`总结本章`、`总结本段`
- 可保存用户自己的 OpenAI API Key
- 可把书用 Apple Books 打开，同时让 ReadAI 作为浮动 AI 面板使用

## 运行

```sh
bash scripts/build_app.sh
open .build/ReadAI.app
```

## 测试

```sh
bash scripts/e2e_books.sh
```

也可以单独测试解析：

```sh
bash scripts/e2e_book_core.sh
```

## Features

- PDF reading via PDFKit
- EPUB reading via local extraction
- Hideable left local library: add multiple PDF/EPUB files and reopen them from the app
- Book-style page navigation with page count and Prev/Next controls
- Reading modes: paginated Page mode and vertical Scroll mode
- Reader fullscreen mode: hide Library/AI and let PDF/EPUB fill the window
- EPUB typography controls: font size and line spacing
- Apple Books companion mode: open a local book in Books, keep ReadAI as a floating AI pane
- GPT-style back-and-forth chat with book excerpt and conversation history
- Select text in the reader and click `询问AI` to summarize it
- AI quick actions: `总结本章` and `总结本段`
- OpenAI API key saved locally

## Run

```sh
bash scripts/build_app.sh
open .build/ReadAI.app
```

## E2E

```sh
bash scripts/e2e_books.sh
```

Core parsing can also be checked separately:

```sh
bash scripts/e2e_book_core.sh
```
