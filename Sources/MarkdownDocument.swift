import AppKit
import UniformTypeIdentifiers

let markdownType = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)

@objc(MarkdownDocument)
final class MarkdownDocument: NSDocument {
    private(set) var source = ""
    private var encoding: String.Encoding = .utf8
    private var hasUTF8BOM = false
    private var lineEnding = "\n"
    private var editTimer: Timer?
    private var focusSavePending = false

    override class var autosavesInPlace: Bool { false }

    override init() {
        super.init()
        hasUndoManager = true
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let marker = Data([0xEF, 0xBB, 0xBF])
        let hasBOM = data.starts(with: marker)
        let bytes = hasBOM ? Data(data.dropFirst(marker.count)) : data
        let detectedEncoding: String.Encoding
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) ||
           bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            detectedEncoding = .utf32
        } else if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            detectedEncoding = .utf16
        } else {
            detectedEncoding = .utf8
        }
        guard let decoded = String(data: bytes, encoding: detectedEncoding), !decoded.contains("\0") else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInapplicableStringEncodingError,
                          userInfo: [NSLocalizedDescriptionKey: "无法读取此 Markdown。应用支持 UTF-8 和带 BOM 的 UTF-16、UTF-32 文本。"])
        }
        encoding = detectedEncoding
        hasUTF8BOM = hasBOM && detectedEncoding == .utf8
        lineEnding = decoded.contains("\r\n") ? "\r\n" : "\n"
        source = decoded.replacingOccurrences(of: "\r\n", with: "\n")
                        .replacingOccurrences(of: "\r", with: "\n")
    }

    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        flushEdit()
        editor?.reloadSource()
        record("重新载入")
    }

    override func data(ofType typeName: String) throws -> Data {
        let contents = lineEnding == "\n" ? source : source.replacingOccurrences(of: "\n", with: lineEnding)
        guard let encoded = contents.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return hasUTF8BOM ? Data([0xEF, 0xBB, 0xBF]) + encoded : encoded
    }

    override func makeWindowControllers() {
        addWindowController(EditorWindow(document: self))
        record(fileURL == nil ? "新建" : "打开")
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = [markdownType]
        savePanel.isExtensionHidden = false
        savePanel.canCreateDirectories = true
        guard super.prepareSavePanel(savePanel) else { return false }
        if fileURL == nil, let directory = AppSettings.defaultSaveDirectory,
           (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            savePanel.directoryURL = directory
        }
        return true
    }

    override func save(to url: URL, ofType typeName: String, for operation: SaveOperationType,
                       completionHandler: @escaping (Error?) -> Void) {
        switch operation {
        case .saveOperation, .saveAsOperation, .saveToOperation:
            editor?.endTypingUndoGroup()
            flushEdit()
            let action: String
            if operation == .saveOperation {
                action = focusSavePending ? "自动保存" : "保存"
            } else {
                action = fileURL == nil ? "保存" : "另存为"
            }
            super.save(to: url, ofType: typeName, for: operation) { error in
                if error == nil {
                    self.record(action, at: url)
                    self.editor?.refreshPreview()
                }
                completionHandler(error)
            }
        default:
            super.save(to: url, ofType: typeName, for: operation, completionHandler: completionHandler)
        }
    }

    func prepareForQuitReview() {
        editor?.endTypingUndoGroup()
    }

    func saveAfterLosingFocus() {
        guard (NSApp as? MarkdownApp)?.isReviewingQuit != true,
              AppSettings.autosaveOnFocusLoss, fileURL != nil, fileType != nil,
              isDocumentEdited, !focusSavePending else { return }
        focusSavePending = true
        save(withDelegate: self, didSave: #selector(focusSaveFinished(_:didSave:contextInfo:)), contextInfo: nil)
    }

    @objc private func focusSaveFinished(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        focusSavePending = false
    }

    override func close() {
        flushEdit()
        super.close()
    }

    func changeSource(_ value: String) {
        guard value != source else { return }
        source = value
        editTimer?.invalidate()
        editTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.flushEdit()
        }
    }

    func flushEdit() {
        guard let timer = editTimer else { return }
        timer.invalidate()
        editTimer = nil
        record("编辑")
    }

    func record(_ action: String, at url: URL? = nil) {
        let location = url ?? fileURL
        OperationHistory.shared.append(action, name: location?.lastPathComponent ?? displayName,
                                       path: location?.path)
    }

    private var editor: EditorWindow? { windowControllers.first as? EditorWindow }
}
