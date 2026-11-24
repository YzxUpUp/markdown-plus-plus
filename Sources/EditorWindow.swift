import AppKit

final class EditorWindow: NSWindowController, NSTextViewDelegate, NSTextStorageDelegate, NSSplitViewDelegate {
    private weak var markdown: MarkdownDocument?
    private let textView = NSTextView(frame: .zero)
    private let editorScroll = NSScrollView()
    private let preview = MarkdownPreview()
    private let split = NSSplitView()
    private let footer = NSTextField(labelWithString: "")
    private var previewWork: DispatchWorkItem?
    private let modes = NSSegmentedControl(labels: ["编辑", "分栏", "预览"], trackingMode: .selectOne,
                                           target: nil, action: nil)

    init(document: MarkdownDocument) {
        markdown = document
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 690),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.minSize = NSSize(width: 760, height: 400)
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("MarkdownEditor")
        if !window.setFrameUsingName("MarkdownEditor") { window.center() }
        window.titlebarSeparatorStyle = .line
        window.isRestorable = false

        configureEditor()
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = self
        split.addArrangedSubview(editorScroll)
        split.addArrangedSubview(preview.webView)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        let content = NSView()
        let toolbar = makeToolbar()
        let topRule = NSBox()
        topRule.boxType = .separator
        let bottomRule = NSBox()
        bottomRule.boxType = .separator
        footer.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        footer.textColor = .secondaryLabelColor
        for view in [toolbar, topRule, split, bottomRule, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        window.contentView = content
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            toolbar.heightAnchor.constraint(equalToConstant: 47),
            topRule.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            topRule.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.bottomAnchor.constraint(equalTo: bottomRule.topAnchor),
            bottomRule.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bottomRule.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bottomRule.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -5),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -5)
        ])
        let initialMode: EditorMode = document.fileURL == nil ? .split : AppSettings.openingMode
        window.initialFirstResponder = initialMode == .preview ? preview.webView : textView
        modes.selectedSegment = initialMode.rawValue
        reloadSource()
        changeMode(record: false)

        NotificationCenter.default.addObserver(self, selector: #selector(windowLostFocus),
                                               name: NSWindow.didResignKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationLostFocus),
                                               name: NSApplication.didResignActiveNotification, object: NSApp)
    }

    required init?(coder: NSCoder) { nil }

    private func configureEditor() {
        editorScroll.hasVerticalScroller = true
        editorScroll.autohidesScrollers = true
        editorScroll.borderType = .noBorder
        editorScroll.documentView = textView

        textView.delegate = self
        textView.textStorage?.delegate = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFindBar = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 17, height: 22)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel("Markdown 源码")
    }

    private func makeToolbar() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 7

        stack.addArrangedSubview(popup("标题", [
            ("正文", #selector(heading(_:)), 0)
        ] + (1...6).map { ("标题 \($0)", #selector(heading(_:)), $0) }))
        stack.addArrangedSubview(popup("字号",
            [12, 14, 16, 18, 20, 24, 28, 32].map { ("\($0) px", #selector(fontSize(_:)), $0) }))
        stack.addArrangedSubview(button("粗体", symbol: "bold", action: #selector(bold)))
        stack.addArrangedSubview(button("斜体", symbol: "italic", action: #selector(italic)))
        stack.addArrangedSubview(button("删除线", symbol: "strikethrough", action: #selector(strike)))
        stack.addArrangedSubview(popup("列表", [
            ("无序列表", #selector(list(_:)), 0), ("有序列表", #selector(list(_:)), 1)
        ]))
        stack.addArrangedSubview(button("插入链接", symbol: "link", action: #selector(link)))
        stack.addArrangedSubview(button("插入表格", symbol: "tablecells", action: #selector(table)))
        stack.addArrangedSubview(popup("插入", [
            ("图片", #selector(image)), ("引用", #selector(quote)),
            ("行内代码", #selector(inlineCode)), ("代码块", #selector(codeBlock)),
            ("分隔线", #selector(rule))
        ].map { ($0.0, $0.1, 0) }))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        modes.segmentStyle = .rounded
        modes.target = self
        modes.action = #selector(modeChanged)
        modes.setAccessibilityLabel("显示模式")
        for index in 0...2 { modes.setWidth(48, forSegment: index) }
        stack.addArrangedSubview(modes)
        stack.addArrangedSubview(button("操作记录", symbol: "clock.arrow.circlepath", action: #selector(showHistory)))
        stack.addArrangedSubview(button("设置", symbol: "gearshape", action: #selector(showSettings)))
        return stack
    }

    private func popup(_ title: String, _ commands: [(String, Selector, Int)]) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: true)
        popup.addItem(withTitle: title)
        popup.setAccessibilityLabel(title)
        for (label, action, tag) in commands {
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.target = self
            item.tag = tag
            popup.menu?.addItem(item)
        }
        return popup
    }

    private func button(_ label: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)
                              ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.widthAnchor.constraint(equalToConstant: 29).isActive = true
        return button
    }

    func reloadSource() {
        textView.string = markdown?.source ?? ""
        updateFooter()
        refreshPreview()
    }

    func refreshPreview() {
        guard let markdown else { return }
        previewWork?.cancel()
        preview.render(source: markdown.source, documentURL: markdown.fileURL)
    }

    func endTypingUndoGroup() { textView.breakUndoCoalescing() }

    func undoManager(for view: NSTextView) -> UndoManager? { markdown?.undoManager }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        markdown?.changeSource(textStorage.string)
        updateFooter()
        previewWork?.cancel()
        guard modes.selectedSegment != EditorMode.source.rawValue else { return }
        let work = DispatchWorkItem { [weak self] in self?.refreshPreview() }
        previewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(160), execute: work)
    }

    func textViewDidChangeSelection(_ notification: Notification) { updateFooter() }

    private func updateFooter() {
        let selection = textView.selectedRange()
        let text = textView.string as NSString
        let offset = min(selection.location, text.length)
        let before = text.substring(to: offset)
        let parts = before.split(separator: "\n", omittingEmptySubsequences: false)
        let line = max(1, parts.count)
        let column = (parts.last?.count ?? 0) + 1
        footer.stringValue = "Markdown     第 \(line) 行，第 \(column) 列"
    }

    func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(max(proposedPosition, 220), max(220, splitView.bounds.width - 220))
    }

    @objc private func modeChanged() { changeMode(record: true) }

    @objc func showSource() { selectMode(.source) }
    @objc func showSplit() { selectMode(.split) }
    @objc func showPreview() { selectMode(.preview) }

    private func selectMode(_ mode: EditorMode) {
        guard modes.selectedSegment != mode.rawValue else { return }
        modes.selectedSegment = mode.rawValue
        changeMode(record: true)
    }

    private func changeMode(record: Bool) {
        guard let mode = EditorMode(rawValue: modes.selectedSegment) else { return }
        if record {
            markdown?.flushEdit()
            markdown?.record(mode.title)
        }
        editorScroll.isHidden = mode == .preview
        preview.webView.isHidden = mode == .source
        window?.contentView?.layoutSubtreeIfNeeded()
        split.adjustSubviews()
        if mode == .split { split.setPosition((split.bounds.width - split.dividerThickness) / 2, ofDividerAt: 0) }
        if mode == .preview { window?.makeFirstResponder(preview.webView) }
        else { window?.makeFirstResponder(textView) }
        if mode != .source { refreshPreview() }
    }

    @objc private func showHistory() { NSApp.sendAction(#selector(AppDelegate.showHistory(_:)), to: nil, from: self) }

    @objc private func showSettings() {
        NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: NSApp.delegate, from: self)
    }

    @objc private func applicationLostFocus() {
        if let window, window === (NSApp.keyWindow ?? NSApp.mainWindow) { windowLostFocus() }
    }

    @objc private func windowLostFocus() {
        guard AppSettings.autosaveOnFocusLoss, (NSApp as? MarkdownApp)?.isReviewingQuit != true else { return }
        // Let AppKit finish committing edits and attaching any modal sheet.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, window.attachedSheet == nil,
                  !window.isKeyWindow || !NSApp.isActive,
                  window.isVisible || window.isMiniaturized || NSApp.isHidden else { return }
            self.markdown?.saveAfterLosingFocus()
        }
    }

    private var sourceText: NSString { textView.string as NSString }
    private var selection: NSRange { textView.selectedRange() }
    private var selectedText: String { sourceText.substring(with: selection) }

    private func replace(_ range: NSRange, with text: String, selecting newSelection: NSRange? = nil) {
        if modes.selectedSegment == EditorMode.preview.rawValue { selectMode(.split) }
        window?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: range, replacementString: text) else { return }
        textView.replaceCharacters(in: range, with: text)
        textView.didChangeText()
        let insertedLength = (text as NSString).length
        textView.setSelectedRange(newSelection ?? NSRange(location: range.location + insertedLength, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
        textView.breakUndoCoalescing()
    }

    private func wrap(_ prefix: String, _ suffix: String, placeholder: String = "文字") {
        let range = selection
        let content = range.length == 0 ? placeholder : selectedText
        replace(range, with: prefix + content + suffix, selecting: NSRange(
            location: range.location + (prefix as NSString).length, length: (content as NSString).length))
    }

    private func changeLines(_ transform: (String, Int) -> String) {
        var affected = selection
        if affected.length > 0, sourceText.character(at: NSMaxRange(affected) - 1) == 10 {
            affected.length -= 1
        }
        let lineRange = sourceText.lineRange(for: affected)
        let current = sourceText.substring(with: lineRange)
        let hasNewline = current.hasSuffix("\n")
        let body = hasNewline ? String(current.dropLast()) : current
        let changed = body.components(separatedBy: "\n").enumerated().map { transform($0.element, $0.offset) }
            .joined(separator: "\n")
        guard changed != body else { return }
        let end = lineRange.location + changed.utf16.count
        let range: NSRange
        if selection.length == 0 {
            let distanceFromEnd = lineRange.location + body.utf16.count - selection.location
            range = NSRange(location: max(lineRange.location, end - distanceFromEnd), length: 0)
        } else {
            range = NSRange(location: lineRange.location, length: changed.utf16.count)
        }
        replace(lineRange, with: changed + (hasNewline ? "\n" : ""), selecting: range)
    }

    @objc private func heading(_ sender: NSMenuItem) {
        changeLines { line, _ in
            let body = line.replacingOccurrences(of: #"^ {0,3}#{1,6}(?:[ \t]+|$)"#, with: "",
                                                options: .regularExpression)
            return sender.tag == 0 ? body : String(repeating: "#", count: sender.tag) + " " + body
        }
    }

    @objc private func fontSize(_ sender: NSMenuItem) {
        let prefix = "<span style=\"font-size: \(sender.tag)px\">"
        if selection.length == 0 {
            wrap(prefix, "</span>")
            return
        }
        let changed = selectedText.components(separatedBy: "\n").map { line in
            line.trimmingCharacters(in: .whitespaces).isEmpty ? line : prefix + line + "</span>"
        }.joined(separator: "\n")
        replace(selection, with: changed, selecting: NSRange(location: selection.location,
                                                              length: (changed as NSString).length))
    }

    @objc func bold() { wrap("**", "**") }
    @objc func italic() { wrap("*", "*") }
    @objc private func strike() { wrap("~~", "~~") }
    @objc private func inlineCode() {
        let runs = selectedText.split(whereSeparator: { $0 != "`" })
        let fence = String(repeating: "`", count: (runs.map(\.count).max() ?? 0) + 1)
        let padding = selectedText.first == "`" || selectedText.last == "`" ? " " : ""
        wrap(fence + padding, padding + fence, placeholder: "代码")
    }
    @objc private func link() { wrap("[", "](https://example.com)", placeholder: "链接文字") }
    @objc private func image() { wrap("![", "](image.png)", placeholder: "图片说明") }
    @objc private func quote() { changeLines { line, _ in "> " + line } }
    @objc private func list(_ sender: NSMenuItem) {
        changeLines { line, index in (sender.tag == 0 ? "- " : "\(index + 1). ") + line }
    }

    private func insertBlock(_ contents: String, firstSelection: String? = nil) {
        let range = selection
        let left = sourceText.substring(to: range.location)
        let right = sourceText.substring(from: NSMaxRange(range))
        let prefix = left.isEmpty || left.hasSuffix("\n\n") ? "" : left.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = right.hasPrefix("\n\n") ? "" : right.hasPrefix("\n") ? "\n" : "\n\n"
        var selected: NSRange?
        if let firstSelection {
            let match = (contents as NSString).range(of: firstSelection)
            if match.location != NSNotFound {
                selected = NSRange(location: range.location + prefix.utf16.count + match.location,
                                   length: match.length)
            }
        }
        replace(range, with: prefix + contents + suffix, selecting: selected)
    }

    @objc private func table() {
        insertBlock("| 列名 | 列名 |\n| --- | --- |\n| 内容 | 内容 |", firstSelection: "列名")
    }

    @objc private func codeBlock() {
        let content = selection.length == 0 ? "代码" : selectedText
        let runs = content.split(whereSeparator: { $0 != "`" })
        let fence = String(repeating: "`", count: max(3, (runs.map(\.count).max() ?? 0) + 1))
        insertBlock(fence + "\n" + content + "\n" + fence, firstSelection: content)
    }

    @objc private func rule() { insertBlock("---") }
}
