import AppKit

final class MarkdownApp: NSApplication {
    private(set) var isReviewingQuit = false

    override func terminate(_ sender: Any?) {
        guard !isReviewingQuit else { return }
        isReviewingQuit = true
        reviewNextDocument()
    }

    private func reviewNextDocument() {
        let documents = NSDocumentController.shared.documents
        for case let document as MarkdownDocument in documents {
            document.prepareForQuitReview()
        }
        guard let document = documents.first(where: \.isDocumentEdited) else {
            super.terminate(nil)
            isReviewingQuit = false
            return
        }

        let alert = NSAlert()
        let name = document.displayName ?? "未命名"
        alert.messageText = "退出前保存对“\(name)”的修改？"
        alert.informativeText = "选择「不保存」会丢弃此文档的未保存修改。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消").keyEquivalent = "\u{1b}"
        alert.addButton(withTitle: "不保存").hasDestructiveAction = true

        if let window = document.windowForSheet, window.attachedSheet == nil {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            alert.beginSheetModal(for: window) { [self] response in
                DispatchQueue.main.async { self.handleQuitResponse(response, for: document) }
            }
        } else {
            handleQuitResponse(alert.runModal(), for: document)
        }
    }

    private func handleQuitResponse(_ response: NSApplication.ModalResponse, for document: NSDocument) {
        switch response {
        case .alertFirstButtonReturn:
            document.save(withDelegate: self, didSave: #selector(quitDocumentDidSave(_:didSave:contextInfo:)),
                          contextInfo: nil)
        case .alertThirdButtonReturn:
            document.close()
            reviewNextDocument()
        default:
            cancelQuitReview(for: document)
        }
    }

    @objc private func quitDocumentDidSave(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        if didSave {
            DispatchQueue.main.async { [self] in reviewNextDocument() }
        } else {
            cancelQuitReview(for: document)
        }
    }

    private func cancelQuitReview(for document: NSDocument) {
        document.windowForSheet?.makeKeyAndOrderFront(nil)
        isReviewingQuit = false
    }
}
