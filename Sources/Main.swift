import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var historyWindow: HistoryWindow?
    private var settingsWindow: SettingsWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = AppSettings.theme.appearance
        _ = NSDocumentController.shared
        buildMenu()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { NSDocumentController.shared.newDocument(nil) }
        return true
    }

    @objc func showHistory(_ sender: Any?) {
        for case let document as MarkdownDocument in NSDocumentController.shared.documents {
            document.flushEdit()
        }
        if historyWindow == nil { historyWindow = HistoryWindow() }
        historyWindow?.reload()
        historyWindow?.showWindow(sender)
        historyWindow?.window?.makeKeyAndOrderFront(sender)
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil { settingsWindow = SettingsWindow() }
        if settingsWindow?.window?.isVisible == false { settingsWindow?.refresh() }
        settingsWindow?.showWindow(sender)
        settingsWindow?.window?.makeKeyAndOrderFront(sender)
    }

    @objc private func setDefaultApp(_ sender: Any?) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: markdownType) { error in
            DispatchQueue.main.async {
                let alert = NSAlert()
                if let error {
                    alert.messageText = "未能设置默认应用"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                } else {
                    alert.messageText = "Markdown++ 已设为默认应用"
                    alert.informativeText = "通过 Finder 打开 Markdown 文件时将使用 Markdown++。"
                }
                if let window = NSApp.keyWindow { alert.beginSheetModal(for: window) }
                else { alert.runModal() }
            }
        }
    }

    private func buildMenu() {
        let menuBar = NSMenu()
        NSApp.mainMenu = menuBar

        func menu(_ title: String) -> NSMenu {
            let root = NSMenuItem()
            let submenu = NSMenu(title: title)
            root.submenu = submenu
            menuBar.addItem(root)
            return submenu
        }

        let app = menu("Markdown++")
        add(app, "关于 Markdown++", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        add(app, "设置…", #selector(showSettings(_:)), ",", target: self)
        add(app, "设为默认 Markdown 应用…", #selector(setDefaultApp(_:)), target: self)
        app.addItem(.separator())
        add(app, "隐藏 Markdown++", #selector(NSApplication.hide(_:)), "h")
        add(app, "退出 Markdown++", #selector(NSApplication.terminate(_:)), "q")

        let file = menu("文件")
        add(file, "新建", #selector(NSDocumentController.newDocument(_:)), "n")
        add(file, "打开…", #selector(NSDocumentController.openDocument(_:)), "o")
        let recentItem = NSMenuItem(title: "打开最近文件", action: nil, keyEquivalent: "")
        let recent = NSMenu(title: recentItem.title)
        recent.delegate = self
        recentItem.submenu = recent
        file.addItem(recentItem)
        file.addItem(.separator())
        add(file, "关闭", #selector(NSWindow.performClose(_:)), "w")
        add(file, "保存", #selector(NSDocument.save(_:)), "s")
        add(file, "另存为…", #selector(NSDocument.saveAs(_:)), "s", modifiers: [.command, .shift])
        add(file, "重新载入已保存版本…", #selector(NSDocument.revertToSaved(_:)))

        let edit = menu("编辑")
        add(edit, "撤销", Selector(("undo:")), "z")
        add(edit, "重做", Selector(("redo:")), "z", modifiers: [.command, .shift])
        edit.addItem(.separator())
        add(edit, "剪切", #selector(NSText.cut(_:)), "x")
        add(edit, "复制", #selector(NSText.copy(_:)), "c")
        add(edit, "粘贴", #selector(NSText.paste(_:)), "v")
        add(edit, "全选", #selector(NSText.selectAll(_:)), "a")
        let find = add(edit, "查找…", #selector(NSTextView.performTextFinderAction(_:)), "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        edit.addItem(.separator())
        add(edit, "粗体", #selector(EditorWindow.bold), "b")
        add(edit, "斜体", #selector(EditorWindow.italic), "i")

        let view = menu("显示")
        add(view, "源码编辑", #selector(EditorWindow.showSource), "1")
        add(view, "同屏预览", #selector(EditorWindow.showSplit), "2")
        add(view, "仅预览", #selector(EditorWindow.showPreview), "3")
        view.addItem(.separator())
        add(view, "操作记录…", #selector(showHistory(_:)), "h", modifiers: [.command, .shift], target: self)
        add(view, "进入全屏", #selector(NSWindow.toggleFullScreen(_:)), "f", modifiers: [.command, .control])

        let windows = menu("窗口")
        NSApp.windowsMenu = windows
        add(windows, "最小化", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, "将所有窗口移到前面", #selector(NSApplication.arrangeInFront(_:)))
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
                     modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let controller = NSDocumentController.shared
        let urls = controller.recentDocumentURLs
        for url in urls {
            let item = add(menu, url.lastPathComponent, #selector(openRecent(_:)), target: self)
            item.representedObject = url
            item.toolTip = url.path
        }
        if !urls.isEmpty { menu.addItem(.separator()) }
        add(menu, "清除最近文件", #selector(NSDocumentController.clearRecentDocuments(_:)), target: controller)
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }
}

@main enum MarkdownApplication {
    static func main() {
        let application = MarkdownApp.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}
