import AppKit

enum EditorMode: Int, CaseIterable {
    case source, split, preview

    var title: String {
        switch self {
        case .source: return "源码编辑"
        case .split: return "同屏预览"
        case .preview: return "仅预览"
        }
    }
}

enum EditorTheme: Int, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "白色"
        case .dark: return "黑色"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppSettings {
    static var autosaveOnFocusLoss: Bool {
        get { UserDefaults.standard.bool(forKey: "autosaveOnFocusLoss") }
        set { UserDefaults.standard.set(newValue, forKey: "autosaveOnFocusLoss") }
    }

    static var openingMode: EditorMode {
        get {
            let value = UserDefaults.standard.object(forKey: "openingMode") as? Int
            return value.flatMap(EditorMode.init(rawValue:)) ?? .split
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "openingMode") }
    }

    static var defaultSaveDirectory: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: "defaultSaveDirectory"), path.hasPrefix("/") else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { UserDefaults.standard.set(newValue?.path, forKey: "defaultSaveDirectory") }
    }

    static var theme: EditorTheme {
        get { EditorTheme(rawValue: UserDefaults.standard.integer(forKey: "editorTheme")) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "editorTheme") }
    }
}

final class SettingsWindow: NSWindowController {
    private let limit = NSTextField(string: "")
    private let autosave = NSButton(checkboxWithTitle: "文档窗口失去焦点时自动保存", target: nil, action: nil)
    private let openingMode = NSPopUpButton()
    private let theme = NSPopUpButton()
    private let saveDirectoryPath = NSTextField(labelWithString: "")
    private var pendingSaveDirectory: URL?
    private lazy var clearDirectoryButton = NSButton(title: "清除", target: self, action: #selector(clearSaveDirectory))
    private let status = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 345),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Markdown++ 设置"
        window.center()

        let historyLabel = NSTextField(labelWithString: "操作记录保留上限")
        let range = NSTextField(labelWithString: "100–9999 条")
        range.textColor = .secondaryLabelColor
        range.font = .systemFont(ofSize: 12)
        limit.alignment = .right
        limit.setAccessibilityLabel(historyLabel.stringValue)
        limit.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let historyControl = NSStackView(views: [limit, range])
        historyControl.alignment = .firstBaseline
        historyControl.spacing = 8

        let modeLabel = NSTextField(labelWithString: "文件打开模式")
        openingMode.addItems(withTitles: EditorMode.allCases.map(\.title))
        openingMode.setAccessibilityLabel(modeLabel.stringValue)
        let themeLabel = NSTextField(labelWithString: "主题")
        theme.addItems(withTitles: EditorTheme.allCases.map(\.title))
        theme.setAccessibilityLabel(themeLabel.stringValue)
        let autosaveLabel = NSTextField(labelWithString: "自动保存")
        let autosaveHint = NSTextField(labelWithString: "已有文件自动保存，新文件先按 ⌘S 选择位置。")
        autosaveHint.font = .systemFont(ofSize: 12)
        autosaveHint.textColor = .secondaryLabelColor

        let directoryLabel = NSTextField(labelWithString: "默认保存文件夹")
        saveDirectoryPath.font = .systemFont(ofSize: 12)
        saveDirectoryPath.lineBreakMode = .byTruncatingMiddle
        saveDirectoryPath.setAccessibilityLabel(directoryLabel.stringValue)
        saveDirectoryPath.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let chooseDirectory = NSButton(title: "选择文件夹…", target: self, action: #selector(chooseSaveDirectory))
        let directoryButtons = NSStackView(views: [chooseDirectory, clearDirectoryButton])
        directoryButtons.spacing = 8

        let grid = NSGridView(views: [
            [historyLabel, historyControl],
            [modeLabel, openingMode],
            [themeLabel, theme],
            [autosaveLabel, autosave],
            [NSGridCell.emptyContentView, autosaveHint],
            [directoryLabel, saveDirectoryPath],
            [NSGridCell.emptyContentView, directoryButtons]
        ])
        grid.columnSpacing = 15
        grid.rowSpacing = 12
        grid.rowAlignment = .firstBaseline
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        let apply = NSButton(title: "应用", target: self, action: #selector(applySettings))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        status.font = .systemFont(ofSize: 12)
        status.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [status, apply])
        footer.alignment = .firstBaseline
        footer.spacing = 12

        let divider = NSBox()
        divider.boxType = .separator
        let content = NSView()
        for view in [grid, divider, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        window.contentView = content
        window.initialFirstResponder = limit
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 23),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            divider.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 16),
            footer.leadingAnchor.constraint(equalTo: divider.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: divider.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        limit.stringValue = String(OperationHistory.shared.limit)
        openingMode.selectItem(at: AppSettings.openingMode.rawValue)
        theme.selectItem(at: AppSettings.theme.rawValue)
        autosave.state = AppSettings.autosaveOnFocusLoss ? .on : .off
        pendingSaveDirectory = AppSettings.defaultSaveDirectory
        updateSaveDirectoryPath()
        status.textColor = .secondaryLabelColor
        status.stringValue = "调低上限会移除超出上限的最旧记录。"
    }

    @objc private func chooseSaveDirectory() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择默认保存文件夹"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = pendingSaveDirectory
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            self?.pendingSaveDirectory = url
            self?.updateSaveDirectoryPath()
        }
    }

    @objc private func clearSaveDirectory() {
        pendingSaveDirectory = nil
        updateSaveDirectoryPath()
    }

    private func updateSaveDirectoryPath() {
        saveDirectoryPath.stringValue = pendingSaveDirectory.map { ($0.path as NSString).abbreviatingWithTildeInPath }
            ?? "未设置，首次保存时手动选择"
        saveDirectoryPath.toolTip = pendingSaveDirectory?.path
        saveDirectoryPath.textColor = pendingSaveDirectory == nil ? .secondaryLabelColor : .labelColor
        clearDirectoryButton.isEnabled = pendingSaveDirectory != nil
    }

    @objc private func applySettings() {
        guard let value = Int(limit.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              (100...9999).contains(value) else {
            status.textColor = .systemRed
            status.stringValue = "请输入 100 到 9999 之间的整数。"
            return
        }
        guard let mode = EditorMode(rawValue: openingMode.indexOfSelectedItem),
              let selectedTheme = EditorTheme(rawValue: theme.indexOfSelectedItem) else { return }
        OperationHistory.shared.setLimit(value)
        AppSettings.autosaveOnFocusLoss = autosave.state == .on
        AppSettings.openingMode = mode
        AppSettings.theme = selectedTheme
        AppSettings.defaultSaveDirectory = pendingSaveDirectory
        NSApp.appearance = selectedTheme.appearance
        status.textColor = .secondaryLabelColor
        status.stringValue = "设置已保存。"
    }
}
