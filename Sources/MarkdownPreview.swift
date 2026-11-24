import AppKit
import UniformTypeIdentifiers
import WebKit

final class MarkdownPreview: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private let images = DocumentImages()
    private var documentURL: URL?
    private var source = ""
    private var ready = false

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(images, forURLScheme: "markdown-image")
        configuration.userContentController.add(LinkHandler(preview: self), name: "openMarkdownLink")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.setAccessibilityLabel("Markdown 预览")
        if let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Preview") {
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        return view
    }()

    func render(source: String, documentURL: URL?) {
        self.source = source
        self.documentURL = documentURL
        images.setDirectory(documentURL?.deletingLastPathComponent())
        renderCurrentSource()
    }

    private func renderCurrentSource() {
        guard ready else { return }
        webView.callAsyncJavaScript("window.renderMarkdown(source, revision)",
                                    arguments: ["source": source, "revision": images.revision],
                                    in: nil, in: .page, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        renderCurrentSource()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        webView.reload()
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let isPreviewPage = action.request.url == Bundle.main.url(
            forResource: "index", withExtension: "html", subdirectory: "Preview")
        decisionHandler(isPreviewPage ? .allow : .cancel)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let target = message.body as? String, let relative = URL(string: target) else { return }
        if let scheme = relative.scheme?.lowercased() {
            if ["http", "https", "mailto"].contains(scheme) { NSWorkspace.shared.open(relative) }
            return
        }
        if target.hasPrefix("//"), let url = URL(string: "https:" + target) {
            NSWorkspace.shared.open(url)
        } else if let documentURL, !target.hasPrefix("/"),
                  let url = URL(string: target, relativeTo: documentURL)?.absoluteURL, url.isFileURL {
            let file = URL(fileURLWithPath: url.path)
            let type = try? file.resourceValues(forKeys: [.contentTypeKey]).contentType
            if type?.conforms(to: markdownType) == true {
                NSDocumentController.shared.openDocument(withContentsOf: file, display: true) { _, _, error in
                    if let error { NSApp.presentError(error) }
                }
            } else if type?.conforms(to: .image) == true || type?.conforms(to: .pdf) == true {
                NSWorkspace.shared.open(file)
            }
        }
    }
}

private final class LinkHandler: NSObject, WKScriptMessageHandler {
    weak var preview: MarkdownPreview?

    init(preview: MarkdownPreview) {
        self.preview = preview
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        preview?.userContentController(userContentController, didReceive: message)
    }
}

private final class DocumentImages: NSObject, WKURLSchemeHandler {
    private var directory: URL?
    private(set) var revision = 0

    func setDirectory(_ url: URL?) {
        guard directory != url else { return }
        directory = url
        revision += 1
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let directory, let request = task.request.url,
              let parameters = URLComponents(url: request, resolvingAgainstBaseURL: false)?.queryItems,
              parameters.first(where: { $0.name == "revision" })?.value == String(revision),
              let source = parameters.first(where: { $0.name == "source" })?.value,
              !source.hasPrefix("/"), URL(string: source)?.scheme == nil,
              let url = URL(string: source, relativeTo: directory)?.absoluteURL, url.isFileURL,
              let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
              let mimeType = type.preferredMIMEType,
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let size = values.fileSize, size <= 25 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else {
            task.didFailWithError(URLError(.resourceUnavailable))
            return
        }
        let response = URLResponse(url: request, mimeType: mimeType,
                                   expectedContentLength: data.count, textEncodingName: nil)
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
