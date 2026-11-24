import AppKit

struct HistoryEntry: Codable {
    let date: Date
    let action: String
    let name: String
    let path: String?
}

final class OperationHistory {
    static let shared = OperationHistory()
    static let didChange = Notification.Name("MarkdownOperationHistoryDidChange")
    private static let limitKey = "operationHistoryLimit"
    private let file: URL
    private let defaults: UserDefaults
    private(set) var entries: [HistoryEntry]
    private(set) var persistenceError: Error?

    init(file: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.file = file ?? support.appendingPathComponent("Markdown++/History.json")
        do {
            let data = try Data(contentsOf: self.file)
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            entries = []
            if (error as NSError).code != NSFileReadNoSuchFileError { persistenceError = error }
        }
        trim()
    }

    var limit: Int {
        let value = defaults.object(forKey: Self.limitKey) as? Int ?? 100
        return min(9999, max(100, value))
    }

    func setLimit(_ value: Int) {
        guard (100...9999).contains(value) else { return }
        defaults.set(value, forKey: Self.limitKey)
        if trim() { persist() }
        else { NotificationCenter.default.post(name: Self.didChange, object: self) }
    }

    func append(_ action: String, name: String, path: String?) {
        entries.append(HistoryEntry(date: Date(), action: action, name: name, path: path))
        trim()
        persist()
    }

    @discardableResult
    private func trim() -> Bool {
        let excess = entries.count - limit
        guard excess > 0 else { return false }
        entries.removeFirst(excess)
        return true
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error
        }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}

final class HistoryWindow: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private var entries: [HistoryEntry] = []
    private let dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 440),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "操作记录"
        window.minSize = NSSize(width: 560, height: 300)
        window.center()

        for (key, title, width) in [("date", "时间", 170.0), ("action", "操作", 95.0),
                                    ("file", "文件", 160.0), ("path", "路径", 350.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
        table.style = .inset
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(openEntry)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(status)
        window.contentView = content
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -9),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            status.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: OperationHistory.didChange, object: nil)
        reload()
    }

    required init?(coder: NSCoder) { nil }

    @objc func reload() {
        let history = OperationHistory.shared
        entries = Array(history.entries.reversed())
        table.reloadData()
        status.stringValue = history.persistenceError == nil
            ? "已保留 \(entries.count) 条记录，上限 \(history.limit) 条"
            : "本地记录读写失败：\(history.persistenceError?.localizedDescription ?? "")"
    }

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        let entry = entries[row]
        let value: String
        switch identifier.rawValue {
        case "date": value = dateFormat.string(from: entry.date)
        case "action": value = entry.action
        case "file": value = entry.name
        default: value = entry.path ?? "—"
        }
        let label = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
            ?? NSTextField(labelWithString: "")
        label.identifier = identifier
        label.stringValue = value
        label.toolTip = value
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }

    @objc private func openEntry() {
        let row = table.clickedRow
        guard entries.indices.contains(row), let path = entries[row].path else { return }
        NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path), display: true) {
            _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }
}
