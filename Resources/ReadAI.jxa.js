ObjC.import("Cocoa");
ObjC.import("Foundation");
ObjC.import("PDFKit");

var app = $.NSApplication.sharedApplication;
var controller = null;
var window = null;
var rootView = null;
var libraryPane = null;
var libraryDivider = null;
var leftPane = null;
var readerDivider = null;
var rightPane = null;
var libraryScroll = null;
var readerBody = null;
var pageLabel = null;
var activePDFView = null;
var activePDFDocument = null;
var epubTextView = null;
var epubScrollView = null;
var epubPages = [];
var epubPageIndex = 0;
var readerMode = "empty";
var readingStyle = "page";
var readerFontSize = 18;
var readerLineSpacing = 8;
var messagesView = null;
var promptView = null;
var chatHistory = [];
var currentBook = { title: "", text: "", path: "", chapters: [] };
var libraryPaths = [];
var libraryVisible = true;
var floatingWindow = false;
var readingFullscreen = false;
var LIBRARY_WIDTH = 220;
var AI_WIDTH = 379;

function s(value) {
  return $(String(value || ""));
}

function js(value) {
  return ObjC.unwrap(value) || "";
}

function parseArgs(argv) {
  var options = {
    statusPath: null,
    exitAfterOpen: false,
    turnPages: false,
    readingStyle: null,
    fontSize: null,
    lineSpacing: null,
    readerFullscreen: false,
    startupBookPath: null
  };
  for (var i = 0; i < argv.length; i += 1) {
    var arg = String(argv[i]);
    if (arg === "--e2e-exit-after-open") {
      options.exitAfterOpen = true;
    } else if (arg === "--e2e-turn-pages") {
      options.turnPages = true;
    } else if (arg === "--e2e-reading-style" && i + 1 < argv.length) {
      options.readingStyle = String(argv[i + 1]);
      i += 1;
    } else if (arg === "--e2e-font-size" && i + 1 < argv.length) {
      options.fontSize = Number(argv[i + 1]);
      i += 1;
    } else if (arg === "--e2e-line-spacing" && i + 1 < argv.length) {
      options.lineSpacing = Number(argv[i + 1]);
      i += 1;
    } else if (arg === "--e2e-reader-fullscreen") {
      options.readerFullscreen = true;
    } else if (arg === "--e2e-status-path" && i + 1 < argv.length) {
      options.statusPath = String(argv[i + 1]);
      i += 1;
    } else if (arg.indexOf("--e2e-status-path=") === 0) {
      options.statusPath = arg.slice("--e2e-status-path=".length);
    } else if (arg.indexOf("--") !== 0 && options.startupBookPath === null) {
      options.startupBookPath = arg;
    }
  }
  return options;
}

function writeJSON(path, payload) {
  if (!path) return;
  s(JSON.stringify(payload, null, 2)).writeToFileAtomicallyEncodingError(
    path,
    true,
    $.NSUTF8StringEncoding,
    null
  );
}

function readUTF8File(path) {
  return js($.NSString.stringWithContentsOfFileEncodingError(
    s(path),
    $.NSUTF8StringEncoding,
    null
  ));
}

function runTask(path, args) {
  var task = $.NSTask.alloc.init;
  var outPipe = $.NSPipe.pipe;
  var errPipe = $.NSPipe.pipe;
  task.setLaunchPath(s(path));
  task.setArguments($(args));
  task.setStandardOutput(outPipe);
  task.setStandardError(errPipe);
  task.launch;
  task.waitUntilExit;

  var outData = outPipe.fileHandleForReading.readDataToEndOfFile;
  var errData = errPipe.fileHandleForReading.readDataToEndOfFile;
  var out = js($.NSString.alloc.initWithDataEncoding(outData, $.NSUTF8StringEncoding));
  var err = js($.NSString.alloc.initWithDataEncoding(errData, $.NSUTF8StringEncoding));
  if (task.terminationStatus !== 0) {
    throw new Error(err || out || "Command failed.");
  }
  return out;
}

function clearView(view) {
  while (view.subviews.count > 0) {
    view.subviews.objectAtIndex(0).removeFromSuperview;
  }
}

function defaults() {
  return $.NSUserDefaults.standardUserDefaults;
}

function isBookFile(path) {
  var lower = path.toLowerCase();
  return lower.endsWith(".pdf") || lower.endsWith(".epub");
}

function fileExists(path) {
  return $.NSFileManager.defaultManager.fileExistsAtPath(s(path));
}

function bookName(path) {
  return path.split("/").pop();
}

function loadLibrary() {
  var raw = js(defaults().stringForKey("ReadAIBookPathsJSON"));
  try {
    libraryPaths = JSON.parse(raw || "[]").filter(function (path) {
      return isBookFile(path) && fileExists(path);
    });
  } catch (_) {
    libraryPaths = [];
  }
}

function saveLibrary() {
  defaults().setObjectForKey(s(JSON.stringify(libraryPaths)), "ReadAIBookPathsJSON");
  defaults().synchronize;
}

function loadLibraryVisibility() {
  var stored = defaults().objectForKey("ReadAILibraryVisible");
  libraryVisible = String(stored) === "[id nil]" ? true : Boolean(defaults().boolForKey("ReadAILibraryVisible"));
}

function saveLibraryVisibility() {
  defaults().setBoolForKey(libraryVisible, "ReadAILibraryVisible");
  defaults().synchronize;
}

function loadReadingStyle() {
  var saved = js(defaults().stringForKey("ReadAIReadingStyle"));
  readingStyle = saved === "scroll" ? "scroll" : "page";
}

function saveReadingStyle() {
  defaults().setObjectForKey(s(readingStyle), "ReadAIReadingStyle");
  defaults().synchronize;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function loadReaderTypography() {
  var savedFont = Number(defaults().doubleForKey("ReadAIFontSize"));
  var savedLine = Number(defaults().doubleForKey("ReadAILineSpacing"));
  readerFontSize = savedFont > 0 ? clamp(savedFont, 12, 32) : 18;
  readerLineSpacing = savedLine > 0 ? clamp(savedLine, 0, 24) : 8;
}

function saveReaderTypography() {
  defaults().setDoubleForKey(readerFontSize, "ReadAIFontSize");
  defaults().setDoubleForKey(readerLineSpacing, "ReadAILineSpacing");
  defaults().synchronize;
}

function addBookPath(path) {
  if (!isBookFile(path) || !fileExists(path)) return false;
  if (libraryPaths.indexOf(path) === -1) {
    libraryPaths.push(path);
    saveLibrary();
    renderLibrary();
  }
  return true;
}

function addBookPaths(paths) {
  paths.forEach(function (path) {
    addBookPath(path);
  });
}

function label(text, x, y, width, height, bold) {
  var field = $.NSTextField.alloc.initWithFrame($.NSMakeRect(x, y, width, height));
  field.setStringValue(s(text));
  field.setBezeled(false);
  field.setDrawsBackground(false);
  field.setEditable(false);
  field.setSelectable(false);
  field.setTextColor($.NSColor.labelColor);
  if (bold) field.setFont($.NSFont.boldSystemFontOfSize(15));
  return field;
}

function button(title, x, y, width, height, action) {
  var b = $.NSButton.alloc.initWithFrame($.NSMakeRect(x, y, width, height));
  b.setTitle(s(title));
  b.setBezelStyle($.NSBezelStyleRounded);
  b.setTarget(controller);
  b.setAction($.NSSelectorFromString(action));
  return b;
}

function textScroll(x, y, width, height, editable, bordered) {
  var scroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(x, y, width, height));
  scroll.setHasVerticalScroller(true);
  scroll.setBorderType(bordered === false ? 0 : $.NSBezelBorder);
  scroll.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);

  var view = $.NSTextView.alloc.initWithFrame($.NSMakeRect(0, 0, width, height));
  view.setEditable(Boolean(editable));
  view.setRichText(false);
  view.setFont($.NSFont.systemFontOfSize(14));
  view.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  scroll.setDocumentView(view);
  return { scroll: scroll, view: view };
}

function appendMessage(role, body) {
  chatHistory.push({ role: role, text: body });
  var transcript = chatHistory.map(function (message) {
    return (message.role === "user" ? "You" : "AI") + "\n" + message.text;
  }).join("\n\n");
  messagesView.setString(s(transcript));
  messagesView.scrollRangeToVisible($.NSMakeRange(js(messagesView.string).length, 0));
}

function conversationContext() {
  return chatHistory.slice(-8).map(function (message) {
    return (message.role === "user" ? "User" : "Assistant") + ": " + message.text;
  }).join("\n");
}

function reloadCurrentBook() {
  if (!currentBook.path) return;
  if (readerMode === "pdf" && activePDFDocument) {
    renderPDF(currentBook.path, activePDFDocument);
    return;
  }
  if (readerMode === "epub") {
    renderText(currentBook.path, currentBook.title, currentBook.text);
  }
}

function styledTextStorage() {
  if (!epubTextView) return;
  var range = $.NSMakeRange(0, js(epubTextView.string).length);
  if (range.length <= 0) return;
  var style = $.NSMutableParagraphStyle.alloc.init;
  style.setLineSpacing(readerLineSpacing);
  style.setParagraphSpacing(readerLineSpacing);
  epubTextView.textStorage.addAttributeValueRange(
    $.NSFontAttributeName,
    $.NSFont.systemFontOfSize(readerFontSize),
    range
  );
  epubTextView.textStorage.addAttributeValueRange(
    $.NSParagraphStyleAttributeName,
    style,
    range
  );
}

function applyTypography() {
  if (readerMode !== "epub") return;
  var page = epubPageIndex;
  epubPages = splitTextIntoPages(currentBook.text);
  epubPageIndex = Math.min(page, Math.max(0, epubPages.length - 1));
  if (readingStyle === "scroll") {
    epubTextView.setString(s(currentBook.text || "No readable text."));
    styledTextStorage();
    updateScrollLabel();
  } else {
    renderEPUBPage();
  }
}

function increaseFontSize() {
  readerFontSize = clamp(readerFontSize + 1, 12, 32);
  saveReaderTypography();
  applyTypography();
}

function decreaseFontSize() {
  readerFontSize = clamp(readerFontSize - 1, 12, 32);
  saveReaderTypography();
  applyTypography();
}

function increaseLineSpacing() {
  readerLineSpacing = clamp(readerLineSpacing + 2, 0, 24);
  saveReaderTypography();
  applyTypography();
}

function decreaseLineSpacing() {
  readerLineSpacing = clamp(readerLineSpacing - 2, 0, 24);
  saveReaderTypography();
  applyTypography();
}

function setPageMode() {
  readingStyle = "page";
  saveReadingStyle();
  reloadCurrentBook();
}

function setScrollMode() {
  readingStyle = "scroll";
  saveReadingStyle();
  reloadCurrentBook();
}

function clipText(text, maxLength) {
  var value = String(text || "").trim();
  return value.length > maxLength ? value.slice(0, maxLength) : value;
}

function selectedReaderText() {
  var text = "";

  if (readerMode === "pdf" && activePDFView) {
    var pdfSelection = activePDFView.currentSelection;
    if (pdfSelection) text = js(pdfSelection.string);
  }

  if (!text && epubTextView) {
    var range = epubTextView.selectedRange;
    var length = Number(range.length);
    if (length > 0) {
      var source = js(epubTextView.string);
      var start = Number(range.location);
      text = source.slice(start, start + length);
    }
  }

  return String(text || "").trim();
}

function currentVisibleText() {
  if (readerMode === "pdf" && activePDFView) {
    var page = activePDFView.currentPage;
    if (page) return js(page.string).trim();
  }
  if (readerMode === "epub" && epubTextView) return js(epubTextView.string).trim();
  return (currentBook.text || "").slice(0, 4000).trim();
}

function currentChapterText() {
  if (!currentBook.chapters || currentBook.chapters.length === 0) {
    return currentVisibleText() || currentBook.text || "";
  }

  var visible = currentVisibleText().slice(0, 180).trim();
  var offset = visible ? currentBook.text.indexOf(visible) : -1;
  if (offset < 0 && readingStyle === "page" && epubPages.length > 0 && epubPages[epubPageIndex]) {
    offset = currentBook.text.indexOf(epubPages[epubPageIndex].slice(0, 180));
  }
  if (offset < 0) offset = 0;

  for (var i = 0; i < currentBook.chapters.length; i += 1) {
    var chapter = currentBook.chapters[i];
    if (offset >= chapter.start && offset <= chapter.end) return chapter.text;
  }
  return currentBook.chapters[0].text;
}

function buildReaderShell(title) {
  clearView(leftPane);
  activePDFView = null;
  activePDFDocument = null;
  epubTextView = null;
  epubScrollView = null;

  var paneWidth = Math.max(520, Number(leftPane.bounds.size.width));
  var paneHeight = Math.max(640, Number(leftPane.bounds.size.height));
  var margin = readingFullscreen ? 16 : 24;
  var contentWidth = Math.max(360, paneWidth - margin * 2);
  var topY = paneHeight - 42;
  var controlsY = readingFullscreen ? paneHeight - 42 : paneHeight - 76;
  var bodyY = readingFullscreen ? 50 : 58;
  var bodyHeight = Math.max(320, paneHeight - (readingFullscreen ? 98 : 148));

  if (!readingFullscreen) {
    var libraryButton = button("Library", 24, topY, 78, 28, "toggleLibrary:");
    libraryButton.setAutoresizingMask($.NSViewMinYMargin);
    leftPane.addSubview(libraryButton);
  }

  var titleX = readingFullscreen ? 24 : 112;
  var titleWidth = readingFullscreen ? Math.max(240, paneWidth - 360) : Math.max(180, contentWidth - 88);
  var titleText = label(title || "ReadAI", titleX, topY + 4, titleWidth, 24, true);
  titleText.setLineBreakMode($.NSLineBreakByTruncatingTail);
  titleText.setAutoresizingMask($.NSViewWidthSizable | $.NSViewMinYMargin);
  leftPane.addSubview(titleText);

  var controlX = readingFullscreen ? Math.max(300, paneWidth - 600) : 24;
  var pageMode = button(readingStyle === "page" ? "Page *" : "Page", controlX, controlsY, 72, 28, "pageMode:");
  pageMode.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(pageMode);

  var scrollMode = button(readingStyle === "scroll" ? "Scroll *" : "Scroll", controlX + 78, controlsY, 80, 28, "scrollMode:");
  scrollMode.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(scrollMode);

  var fontMinus = button("A-", controlX + 166, controlsY, 42, 28, "fontDown:");
  fontMinus.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(fontMinus);

  var fontPlus = button("A+", controlX + 214, controlsY, 42, 28, "fontUp:");
  fontPlus.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(fontPlus);

  var lineMinus = button("Line-", controlX + 264, controlsY, 58, 28, "lineDown:");
  lineMinus.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(lineMinus);

  var linePlus = button("Line+", controlX + 328, controlsY, 56, 28, "lineUp:");
  linePlus.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(linePlus);

  var askSelected = button("询问AI", controlX + 392, controlsY, 82, 28, "askSelectedText:");
  askSelected.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(askSelected);

  var fullButton = button(readingFullscreen ? "Exit Full" : "Full", controlX + 482, controlsY, readingFullscreen ? 86 : 58, 28, "toggleReadingFullscreen:");
  fullButton.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(fullButton);

  readerBody = $.NSView.alloc.initWithFrame($.NSMakeRect(margin, bodyY, contentWidth, bodyHeight));
  readerBody.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  readerBody.setWantsLayer(true);
  readerBody.layer.setBackgroundColor($.NSColor.textBackgroundColor.CGColor);
  leftPane.addSubview(readerBody);

  var navX = Math.max(24, Math.floor(paneWidth / 2) - 146);
  var prev = button("Prev", navX, 16, 72, 28, "previousPage:");
  prev.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxXMargin | $.NSViewMaxYMargin);
  leftPane.addSubview(prev);

  pageLabel = label("", navX + 82, 20, 128, 22, false);
  pageLabel.setAlignment($.NSTextAlignmentCenter);
  pageLabel.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxXMargin | $.NSViewMaxYMargin);
  leftPane.addSubview(pageLabel);

  var next = button("Next", navX + 220, 16, 72, 28, "nextPage:");
  next.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxXMargin | $.NSViewMaxYMargin);
  leftPane.addSubview(next);
}

function splitTextIntoPages(text) {
  var source = String(text || "").replace(/\s+/g, " ").trim();
  var pages = [];
  var lineHeight = readerFontSize + readerLineSpacing;
  var approxCharsPerLine = Math.max(18, Math.floor(700 / (readerFontSize * 0.55)));
  var approxLinesPerPage = Math.max(8, Math.floor(560 / lineHeight));
  var pageSize = Math.max(450, approxCharsPerLine * approxLinesPerPage);
  var index = 0;

  while (index < source.length) {
    var end = Math.min(index + pageSize, source.length);
    if (end < source.length) {
      var space = source.lastIndexOf(" ", end);
      if (space > index + 500) end = space;
    }
    pages.push(source.slice(index, end).trim());
    index = end;
  }

  return pages.length ? pages : ["No readable text."];
}

function updatePageLabel(current, total) {
  if (!pageLabel) return;
  pageLabel.setStringValue(s("Page " + current + " / " + total));
}

function currentPDFPageNumber() {
  if (!activePDFView || !activePDFDocument) return 1;
  var page = activePDFView.currentPage;
  if (!page) return 1;
  return Number(activePDFDocument.indexForPage(page)) + 1;
}

function updatePDFPageLabel() {
  if (!activePDFDocument) return;
  updatePageLabel(currentPDFPageNumber(), Number(activePDFDocument.pageCount));
}

function renderEPUBPage() {
  if (!epubTextView) return;
  epubTextView.setString(s(epubPages[epubPageIndex] || ""));
  styledTextStorage();
  updatePageLabel(epubPageIndex + 1, epubPages.length);
}

function updateScrollLabel() {
  if (!pageLabel) return;
  pageLabel.setStringValue(s("Scroll"));
}

function nextPage() {
  if (readerMode === "pdf" && activePDFView) {
    activePDFView.goToNextPage(null);
    updatePDFPageLabel();
    return;
  }
  if (readerMode === "epub" && readingStyle === "scroll" && epubScrollView) {
    epubTextView.scrollPageDown(null);
    updateScrollLabel();
    return;
  }
  if (readerMode === "epub" && epubPageIndex < epubPages.length - 1) {
    epubPageIndex += 1;
    renderEPUBPage();
  }
}

function previousPage() {
  if (readerMode === "pdf" && activePDFView) {
    activePDFView.goToPreviousPage(null);
    updatePDFPageLabel();
    return;
  }
  if (readerMode === "epub" && readingStyle === "scroll" && epubScrollView) {
    epubTextView.scrollPageUp(null);
    updateScrollLabel();
    return;
  }
  if (readerMode === "epub" && epubPageIndex > 0) {
    epubPageIndex -= 1;
    renderEPUBPage();
  }
}

function readerStatus() {
  if (readerMode === "pdf" && activePDFDocument) {
    return {
      pageCount: Number(activePDFDocument.pageCount),
      currentPage: currentPDFPageNumber(),
      readingStyle: readingStyle,
      fontSize: readerFontSize,
      lineSpacing: readerLineSpacing,
      readingFullscreen: readingFullscreen,
    };
  }
  if (readerMode === "epub" && readingStyle === "page") {
    return {
      pageCount: epubPages.length,
      currentPage: epubPageIndex + 1,
      readingStyle: readingStyle,
      fontSize: readerFontSize,
      lineSpacing: readerLineSpacing,
      readingFullscreen: readingFullscreen,
    };
  }
  if (readerMode === "epub") {
    return {
      pageCount: epubPages.length,
      currentPage: 1,
      readingStyle: readingStyle,
      fontSize: readerFontSize,
      lineSpacing: readerLineSpacing,
      readingFullscreen: readingFullscreen,
    };
  }
  return { pageCount: 0, currentPage: 0, readingStyle: readingStyle, fontSize: readerFontSize, lineSpacing: readerLineSpacing, readingFullscreen: readingFullscreen };
}

function renderLibrary() {
  if (!libraryScroll) return;

  var rowHeight = 30;
  var height = Math.max(118, libraryPaths.length * rowHeight + 8);
  var docWidth = Math.max(180, LIBRARY_WIDTH - 34);
  var doc = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, docWidth, height));

  if (libraryPaths.length === 0) {
    var empty = label("Add local PDF or EPUB books.", 8, height - 28, docWidth - 16, 22, false);
    empty.setTextColor($.NSColor.secondaryLabelColor);
    doc.addSubview(empty);
  }

  libraryPaths.forEach(function (path, index) {
    var row = button(bookName(path), 6, height - 32 - index * rowHeight, docWidth - 74, 24, "openLibraryBook:");
    row.setTag(index);
    row.setAlignment($.NSTextAlignmentLeft);
    doc.addSubview(row);

    var books = button("Books", docWidth - 66, height - 32 - index * rowHeight, 60, 24, "openLibraryInBooks:");
    books.setTag(index);
    doc.addSubview(books);
  });

  libraryScroll.setDocumentView(doc);
}

function renderEmpty() {
  clearView(leftPane);
  readerMode = "empty";
  var libraryButton = button("Library", 24, 718, 78, 28, "toggleLibrary:");
  libraryButton.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(libraryButton);

  var addButton = button("Add Book", 110, 718, 92, 28, "openBook:");
  addButton.setAutoresizingMask($.NSViewMinYMargin);
  leftPane.addSubview(addButton);

  var empty = label("Add a local PDF or EPUB to start reading", 0, 0, 520, 30, true);
  empty.setAlignment($.NSTextAlignmentCenter);
  empty.setFrameOrigin($.NSMakePoint(140, 372));
  empty.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxXMargin | $.NSViewMinYMargin | $.NSViewMaxYMargin);
  leftPane.addSubview(empty);
}

function renderPDF(path, doc) {
  readerMode = "pdf";
  buildReaderShell(path.split("/").pop());
  activePDFDocument = doc;
  var pdfView = $.PDFView.alloc.initWithFrame(readerBody.bounds);
  pdfView.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  pdfView.setAutoScales(true);
  pdfView.setDisplayMode(readingStyle === "scroll" ? 1 : 0);
  pdfView.setDisplaysPageBreaks(readingStyle === "scroll");
  pdfView.setDocument(doc);
  activePDFView = pdfView;
  readerBody.addSubview(pdfView);
  updatePDFPageLabel();
  window.setTitle(s("ReadAI - " + path.split("/").pop()));
}

function renderText(path, title, text) {
  readerMode = "epub";
  buildReaderShell(title || path.split("/").pop());
  epubPages = splitTextIntoPages(text);
  epubPageIndex = 0;
  var area = textScroll(0, 0, 752, 650, false);
  area.scroll.setFrame(readerBody.bounds);
  area.view.setFont($.NSFont.systemFontOfSize(readerFontSize));
  area.view.setTextContainerInset($.NSMakeSize(28, 28));
  epubTextView = area.view;
  epubScrollView = area.scroll;
  readerBody.addSubview(area.scroll);
  if (readingStyle === "scroll") {
    epubTextView.setString(s(text || "No readable text."));
    styledTextStorage();
    updateScrollLabel();
  } else {
    renderEPUBPage();
  }
  window.setTitle(s("ReadAI - " + (title || path.split("/").pop())));
}

function resourcesPath(name) {
  return js($.NSProcessInfo.processInfo.environment.objectForKey("READAI_APP_RESOURCES")) + "/" + name;
}

function extractEPUB(path) {
  var temp = js($.NSTemporaryDirectory()) + "readai-epub-" + Date.now() + ".json";
  runTask("/usr/bin/python3", [resourcesPath("epub_extract.py"), "--output", temp, path]);
  var output = readUTF8File(temp);
  $.NSFileManager.defaultManager.removeItemAtPathError(s(temp), null);
  return JSON.parse(output);
}

function loadBook(path) {
  var lower = path.toLowerCase();
  if (lower.endsWith(".pdf")) {
    var url = $.NSURL.fileURLWithPath(s(path));
    var doc = $.PDFDocument.alloc.initWithURL(url);
    if (!doc) throw new Error("Could not read PDF.");
    var text = js(doc.string);
    currentBook = { title: path.split("/").pop(), text: text, path: path, chapters: [] };
    renderPDF(path, doc);
    addBookPath(path);
    var pdfStatus = readerStatus();
    return {
      ok: true,
      kind: "pdf",
      path: path,
      title: currentBook.title.replace(/\.pdf$/i, ""),
      textLength: text.length,
      chapterCount: 0,
      libraryCount: libraryPaths.length,
      pageCount: pdfStatus.pageCount,
      currentPage: pdfStatus.currentPage,
      readingStyle: pdfStatus.readingStyle,
      fontSize: pdfStatus.fontSize,
      lineSpacing: pdfStatus.lineSpacing,
    };
  }

  if (lower.endsWith(".epub")) {
    var epub = extractEPUB(path);
    if (epub.error) throw new Error(epub.error);
    var parts = [];
    var chapterRanges = [];
    var offset = 0;
    epub.chapters.forEach(function (chapter, index) {
      var chapterText = String(chapter.text || "").trim();
      if (!chapterText) return;
      if (parts.length > 0) {
        parts.push("\n\n");
        offset += 2;
      }
      var start = offset;
      parts.push(chapterText);
      offset += chapterText.length;
      chapterRanges.push({
        title: chapter.title || "Chapter " + (index + 1),
        start: start,
        end: offset,
        text: chapterText,
      });
    });
    var fullText = parts.join("");
    currentBook = { title: epub.title, text: fullText, path: path, chapters: chapterRanges };
    renderText(path, epub.title, fullText || "No readable chapters.");
    addBookPath(path);
    var epubStatus = readerStatus();
    return {
      ok: true,
      kind: "epub",
      path: path,
      title: epub.title,
      textLength: fullText.length,
      chapterCount: epub.chapterCount || epub.chapters.length,
      loadedChapterCount: epub.chapters.length,
      libraryCount: libraryPaths.length,
      pageCount: epubStatus.pageCount,
      currentPage: epubStatus.currentPage,
      readingStyle: epubStatus.readingStyle,
      fontSize: epubStatus.fontSize,
      lineSpacing: epubStatus.lineSpacing,
    };
  }

  throw new Error("Unsupported file.");
}

function openPanel() {
  var panel = $.NSOpenPanel.openPanel;
  panel.setAllowsMultipleSelection(true);
  panel.setCanChooseFiles(true);
  panel.setCanChooseDirectories(false);
  panel.setAllowedFileTypes($(["pdf", "epub"]));
  if (panel.runModal === $.NSModalResponseOK) {
    try {
      var paths = [];
      var urls = panel.URLs;
      for (var i = 0; i < urls.count; i += 1) {
        paths.push(js(urls.objectAtIndex(i).path));
      }
      addBookPaths(paths);
      if (paths.length > 0) loadBook(paths[0]);
    } catch (error) {
      showAlert("Open failed", String(error.message || error));
    }
  }
}

function openLibraryIndex(index) {
  var path = libraryPaths[index];
  if (!path) return;
  try {
    loadBook(path);
  } catch (error) {
    showAlert("Open failed", String(error.message || error));
  }
}

function openInBooks(path) {
  if (!path) return;
  try {
    runTask("/usr/bin/open", ["-b", "com.apple.iBooksX", path]);
  } catch (_) {
    runTask("/usr/bin/open", ["-a", "Books", path]);
  }
}

function openLibraryIndexInBooks(index) {
  var path = libraryPaths[index];
  if (!path) return;
  try {
    openInBooks(path);
    currentBook = { title: bookName(path), text: "", path: path, chapters: [] };
  } catch (error) {
    showAlert("Books failed", String(error.message || error));
  }
}

function pasteClipboardToPrompt() {
  var text = js($.NSPasteboard.generalPasteboard.stringForType($.NSPasteboardTypeString));
  if (!text) return;
  var current = js(promptView.string);
  promptView.setString(s(current ? current + "\n" + text : text));
}

function toggleFloatingWindow() {
  floatingWindow = !floatingWindow;
  window.setLevel(floatingWindow ? $.NSFloatingWindowLevel : $.NSNormalWindowLevel);
}

function layoutMainViews() {
  if (!rootView || !leftPane || !rightPane) return;

  var width = Math.max(1040, Number(rootView.bounds.size.width));
  var height = Math.max(640, Number(rootView.bounds.size.height));
  var showLibrary = libraryVisible && !readingFullscreen;
  var showAI = !readingFullscreen;
  var readerX = showLibrary ? LIBRARY_WIDTH + 1 : 0;
  var rightWidth = showAI ? AI_WIDTH : 0;
  var rightX = width - rightWidth;

  if (libraryPane) {
    libraryPane.setHidden(!showLibrary);
    libraryPane.setFrame($.NSMakeRect(0, 0, LIBRARY_WIDTH, height));
  }
  if (libraryDivider) {
    libraryDivider.setHidden(!showLibrary);
    libraryDivider.setFrame($.NSMakeRect(LIBRARY_WIDTH, 0, 1, height));
  }

  leftPane.setFrame($.NSMakeRect(readerX, 0, rightX - readerX - (showAI ? 1 : 0), height));
  if (readerDivider) {
    readerDivider.setHidden(!showAI);
    readerDivider.setFrame($.NSMakeRect(rightX - 1, 0, 1, height));
  }
  rightPane.setHidden(!showAI);
  rightPane.setFrame($.NSMakeRect(rightX, 0, AI_WIDTH, height));
}

function refreshVisibleReader() {
  var mode = readerMode;
  var savedEPUBPage = epubPageIndex;
  var savedPDFPage = currentPDFPageNumber();

  if (mode === "empty") {
    renderEmpty();
    return;
  }

  reloadCurrentBook();

  if (mode === "epub" && readingStyle === "page") {
    epubPageIndex = Math.min(savedEPUBPage, Math.max(0, epubPages.length - 1));
    renderEPUBPage();
  }
  if (mode === "pdf" && activePDFView && activePDFDocument) {
    var page = activePDFDocument.pageAtIndex(savedPDFPage - 1);
    if (page) activePDFView.goToPage(page);
    updatePDFPageLabel();
  }
}

function toggleLibrary() {
  libraryVisible = !libraryVisible;
  saveLibraryVisibility();
  layoutMainViews();
  refreshVisibleReader();
}

function toggleReadingFullscreen() {
  readingFullscreen = !readingFullscreen;
  layoutMainViews();
  refreshVisibleReader();
}

function showAlert(title, message) {
  var alert = $.NSAlert.alloc.init;
  alert.setMessageText(s(title));
  alert.setInformativeText(s(message));
  alert.runModal;
}

function showSettings() {
  var defaults = $.NSUserDefaults.standardUserDefaults;
  var current = js(defaults.stringForKey("ReadAIAPIKey"));

  var input = $.NSSecureTextField.alloc.initWithFrame($.NSMakeRect(0, 0, 360, 24));
  input.setStringValue(s(current));

  var alert = $.NSAlert.alloc.init;
  alert.setMessageText(s("API Key"));
  alert.setInformativeText(s("Paste your OpenAI API key."));
  alert.setAccessoryView(input);
  alert.addButtonWithTitle(s("Save"));
  alert.addButtonWithTitle(s("Cancel"));
  if (alert.runModal === $.NSAlertFirstButtonReturn) {
    defaults.setObjectForKey(input.stringValue, "ReadAIAPIKey");
    defaults.synchronize;
  }
}

function runAIQuestion(question, clearPrompt) {
  question = String(question || "").trim();
  if (!question) return;

  var defaults = $.NSUserDefaults.standardUserDefaults;
  var key = js(defaults.stringForKey("ReadAIAPIKey")).trim();
  if (!key) {
    showSettings();
    key = js(defaults.stringForKey("ReadAIAPIKey")).trim();
    if (!key) return;
  }

  var priorConversation = conversationContext();
  appendMessage("user", question);
  if (clearPrompt && promptView) promptView.setString(s(""));

  try {
    var body = JSON.stringify({
      model: "gpt-4.1-mini",
      input:
        "You are a reading assistant. Answer in the user's language.\n\nBook excerpt:\n" +
        (currentBook.text || "(No excerpt available.)").slice(0, 12000) +
        "\n\nConversation so far:\n" +
        (priorConversation || "(No prior conversation.)") +
        "\n\nQuestion:\n" +
        question,
    });
    var output = runTask("/usr/bin/curl", [
      "-sS",
      "https://api.openai.com/v1/responses",
      "-H",
      "Authorization: Bearer " + key,
      "-H",
      "Content-Type: application/json",
      "-d",
      body,
    ]);
    var json = JSON.parse(output);
    var answer = json.output_text || "";
    if (!answer && json.output && json.output.length) {
      var parts = [];
      json.output.forEach(function (item) {
        (item.content || []).forEach(function (part) {
          if (part.text) parts.push(part.text);
        });
      });
      answer = parts.join("\n");
    }
    appendMessage("assistant", answer || "No response text.");
  } catch (error) {
    appendMessage("assistant", String(error.message || error));
  }
}

function askAI() {
  runAIQuestion(js(promptView.string).trim(), true);
}

function askSelectedText() {
  var text = selectedReaderText();
  if (!text) {
    showAlert("No selection", "Select text in the book first.");
    return;
  }
  runAIQuestion("请总结这段文字，提炼核心观点：\n\n" + clipText(text, 6000), false);
}

function summarizeCurrentChapter() {
  var text = currentChapterText();
  if (!text) {
    showAlert("No text", "Open a book first.");
    return;
  }
  runAIQuestion("请总结本章内容，输出关键观点和一句话结论：\n\n" + clipText(text, 12000), false);
}

function summarizeSelectedOrVisibleText() {
  var text = selectedReaderText() || currentVisibleText();
  if (!text) {
    showAlert("No text", "Select text or open a page first.");
    return;
  }
  runAIQuestion("请总结这段文字，提炼核心观点：\n\n" + clipText(text, 6000), false);
}

function buildWindow() {
  app.setActivationPolicy($.NSApplicationActivationPolicyRegular);

  var style =
    $.NSWindowStyleMaskTitled |
    $.NSWindowStyleMaskClosable |
    $.NSWindowStyleMaskMiniaturizable |
    $.NSWindowStyleMaskResizable;
  window = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(80, 80, 1180, 760),
    style,
    $.NSBackingStoreBuffered,
    false
  );
  window.setTitle(s("ReadAI"));
  window.setMinSize($.NSMakeSize(1040, 640));
  window.setCollectionBehavior($.NSWindowCollectionBehaviorFullScreenPrimary);

  rootView = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 1180, 760));
  rootView.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  rootView.setWantsLayer(true);
  rootView.layer.setBackgroundColor($.NSColor.windowBackgroundColor.CGColor);
  window.setContentView(rootView);

  libraryPane = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, LIBRARY_WIDTH, 760));
  libraryPane.setAutoresizingMask($.NSViewHeightSizable);
  libraryPane.setWantsLayer(true);
  libraryPane.layer.setBackgroundColor($.NSColor.controlBackgroundColor.CGColor);
  rootView.addSubview(libraryPane);

  var libraryTitle = label("Library", 16, 724, 100, 24, true);
  libraryTitle.setAutoresizingMask($.NSViewMinYMargin);
  libraryPane.addSubview(libraryTitle);

  var hideButton = button("Hide", 146, 720, 58, 28, "toggleLibrary:");
  hideButton.setAutoresizingMask($.NSViewMinYMargin);
  libraryPane.addSubview(hideButton);

  var addButton = button("Add Book", 16, 688, 188, 28, "openBook:");
  addButton.setAutoresizingMask($.NSViewMinYMargin);
  libraryPane.addSubview(addButton);

  libraryScroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(16, 16, 188, 660));
  libraryScroll.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  libraryScroll.setHasVerticalScroller(true);
  libraryScroll.setBorderType($.NSBezelBorder);
  libraryPane.addSubview(libraryScroll);
  renderLibrary();

  libraryDivider = $.NSBox.alloc.initWithFrame($.NSMakeRect(LIBRARY_WIDTH, 0, 1, 760));
  libraryDivider.setAutoresizingMask($.NSViewHeightSizable);
  libraryDivider.setBoxType($.NSBoxSeparator);
  rootView.addSubview(libraryDivider);

  leftPane = $.NSView.alloc.initWithFrame($.NSMakeRect(LIBRARY_WIDTH + 1, 0, 580, 760));
  leftPane.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  leftPane.setWantsLayer(true);
  leftPane.layer.setBackgroundColor($.NSColor.textBackgroundColor.CGColor);
  rootView.addSubview(leftPane);

  readerDivider = $.NSBox.alloc.initWithFrame($.NSMakeRect(800, 0, 1, 760));
  readerDivider.setAutoresizingMask($.NSViewMinXMargin | $.NSViewHeightSizable);
  readerDivider.setBoxType($.NSBoxSeparator);
  rootView.addSubview(readerDivider);

  rightPane = $.NSView.alloc.initWithFrame($.NSMakeRect(801, 0, 379, 760));
  rightPane.setAutoresizingMask($.NSViewMinXMargin | $.NSViewHeightSizable);
  rightPane.setWantsLayer(true);
  rightPane.layer.setBackgroundColor($.NSColor.controlBackgroundColor.CGColor);
  rootView.addSubview(rightPane);

  var aiTitle = label("AI", 16, 724, 80, 24, true);
  aiTitle.setAutoresizingMask($.NSViewMinYMargin);
  rightPane.addSubview(aiTitle);

  var floatButton = button("Float", 211, 720, 70, 28, "floatWindow:");
  floatButton.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMinYMargin);
  rightPane.addSubview(floatButton);

  var keyButton = button("Key", 291, 720, 56, 28, "settings:");
  keyButton.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMinYMargin);
  rightPane.addSubview(keyButton);

  var chatPanel = $.NSView.alloc.initWithFrame($.NSMakeRect(16, 16, 331, 692));
  chatPanel.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  chatPanel.setWantsLayer(true);
  chatPanel.layer.setBackgroundColor($.NSColor.textBackgroundColor.CGColor);
  chatPanel.layer.setBorderWidth(1);
  chatPanel.layer.setBorderColor($.NSColor.separatorColor.CGColor);
  rightPane.addSubview(chatPanel);

  var messages = textScroll(10, 150, 311, 542, false, false);
  messages.scroll.setAutoresizingMask($.NSViewWidthSizable | $.NSViewHeightSizable);
  messagesView = messages.view;
  messagesView.setEditable(false);
  messagesView.setFont($.NSFont.systemFontOfSize(14));
  chatPanel.addSubview(messages.scroll);

  var separator = $.NSBox.alloc.initWithFrame($.NSMakeRect(0, 144, 331, 1));
  separator.setBoxType($.NSBoxSeparator);
  separator.setAutoresizingMask($.NSViewWidthSizable | $.NSViewMaxYMargin);
  chatPanel.addSubview(separator);

  var summarizeChapter = button("总结本章", 10, 114, 96, 26, "summarizeChapter:");
  summarizeChapter.setAutoresizingMask($.NSViewMaxYMargin);
  chatPanel.addSubview(summarizeChapter);

  var summarizeText = button("总结本段", 112, 114, 96, 26, "summarizeText:");
  summarizeText.setAutoresizingMask($.NSViewMaxYMargin);
  chatPanel.addSubview(summarizeText);

  var prompt = textScroll(10, 42, 311, 68, true, false);
  prompt.scroll.setAutoresizingMask($.NSViewWidthSizable | $.NSViewMaxYMargin);
  promptView = prompt.view;
  promptView.setFont($.NSFont.systemFontOfSize(14));
  chatPanel.addSubview(prompt.scroll);

  var paste = button("Paste", 151, 8, 76, 28, "pasteClipboard:");
  paste.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxYMargin);
  chatPanel.addSubview(paste);

  var ask = button("Ask", 231, 8, 90, 28, "askAI:");
  ask.setAutoresizingMask($.NSViewMinXMargin | $.NSViewMaxYMargin);
  chatPanel.addSubview(ask);

  layoutMainViews();
  renderEmpty();
  window.makeKeyAndOrderFront(null);
  app.activateIgnoringOtherApps(true);
}

ObjC.registerSubclass({
  name: "ReadAIController",
  protocols: ["NSApplicationDelegate"],
  methods: {
    "applicationShouldTerminateAfterLastWindowClosed:": {
      types: ["bool", ["id"]],
      implementation: function () {
        return true;
      },
    },
    "openBook:": {
      types: ["void", ["id"]],
      implementation: function () {
        openPanel();
      },
    },
    "openLibraryBook:": {
      types: ["void", ["id"]],
      implementation: function (sender) {
        openLibraryIndex(sender.tag);
      },
    },
    "openLibraryInBooks:": {
      types: ["void", ["id"]],
      implementation: function (sender) {
        openLibraryIndexInBooks(sender.tag);
      },
    },
    "pasteClipboard:": {
      types: ["void", ["id"]],
      implementation: function () {
        pasteClipboardToPrompt();
      },
    },
    "floatWindow:": {
      types: ["void", ["id"]],
      implementation: function () {
        toggleFloatingWindow();
      },
    },
    "toggleLibrary:": {
      types: ["void", ["id"]],
      implementation: function () {
        toggleLibrary();
      },
    },
    "toggleReadingFullscreen:": {
      types: ["void", ["id"]],
      implementation: function () {
        toggleReadingFullscreen();
      },
    },
    "previousPage:": {
      types: ["void", ["id"]],
      implementation: function () {
        previousPage();
      },
    },
    "nextPage:": {
      types: ["void", ["id"]],
      implementation: function () {
        nextPage();
      },
    },
    "pageMode:": {
      types: ["void", ["id"]],
      implementation: function () {
        setPageMode();
      },
    },
    "scrollMode:": {
      types: ["void", ["id"]],
      implementation: function () {
        setScrollMode();
      },
    },
    "fontDown:": {
      types: ["void", ["id"]],
      implementation: function () {
        decreaseFontSize();
      },
    },
    "fontUp:": {
      types: ["void", ["id"]],
      implementation: function () {
        increaseFontSize();
      },
    },
    "lineDown:": {
      types: ["void", ["id"]],
      implementation: function () {
        decreaseLineSpacing();
      },
    },
    "lineUp:": {
      types: ["void", ["id"]],
      implementation: function () {
        increaseLineSpacing();
      },
    },
    "askSelectedText:": {
      types: ["void", ["id"]],
      implementation: function () {
        askSelectedText();
      },
    },
    "summarizeChapter:": {
      types: ["void", ["id"]],
      implementation: function () {
        summarizeCurrentChapter();
      },
    },
    "summarizeText:": {
      types: ["void", ["id"]],
      implementation: function () {
        summarizeSelectedOrVisibleText();
      },
    },
    "settings:": {
      types: ["void", ["id"]],
      implementation: function () {
        showSettings();
      },
    },
    "askAI:": {
      types: ["void", ["id"]],
      implementation: function () {
        askAI();
      },
    },
  },
});

function run(argv) {
  controller = $.ReadAIController.alloc.init;
  app.setDelegate(controller);

  var options = parseArgs(argv);
  loadLibrary();
  loadLibraryVisibility();
  loadReadingStyle();
  loadReaderTypography();
  if (options.readingStyle === "scroll" || options.readingStyle === "page") {
    readingStyle = options.readingStyle;
  }
  if (options.fontSize) {
    readerFontSize = clamp(options.fontSize, 12, 32);
  }
  if (options.lineSpacing || options.lineSpacing === 0) {
    readerLineSpacing = clamp(options.lineSpacing, 0, 24);
  }
  buildWindow();

  var status = null;
  try {
    if (options.startupBookPath) {
      status = loadBook(options.startupBookPath);
      if (options.readerFullscreen) {
        readingFullscreen = true;
        layoutMainViews();
        refreshVisibleReader();
        var fullStatus = readerStatus();
        status.pageCount = fullStatus.pageCount;
        status.currentPage = fullStatus.currentPage;
        status.readingFullscreen = fullStatus.readingFullscreen;
      }
      if (options.turnPages) {
        var beforeTurn = readerStatus();
        nextPage();
        var afterTurn = readerStatus();
        status.beforeTurnPage = beforeTurn.currentPage;
        status.afterTurnPage = afterTurn.currentPage;
        status.turnPageWorked = afterTurn.currentPage > beforeTurn.currentPage || afterTurn.pageCount <= 1;
        status.pageCount = afterTurn.pageCount;
        status.currentPage = afterTurn.currentPage;
        status.readingFullscreen = afterTurn.readingFullscreen;
      }
    } else if (options.statusPath) {
      status = { ok: false, error: "Missing book path." };
    }
  } catch (error) {
    status = {
      ok: false,
      path: options.startupBookPath || "",
      error: String(error.message || error),
    };
  }

  if (options.statusPath) writeJSON(options.statusPath, status);
  if (options.exitAfterOpen) return status && status.ok ? 0 : 1;

  app.run;
  return 0;
}
