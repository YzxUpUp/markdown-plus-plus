# Markdown++

[中文](#中文) · [English](#english)

## 中文

Markdown++ 是一款原生 macOS Markdown 编辑器，支持新建、打开、保存和另存文件。默认左侧编辑源码，右侧实时预览，也可以切换到单独的编辑或预览模式。

- `⌘N` 新建，`⌘O` 打开，`⌘S` 保存，`⇧⌘S` 另存为。
- `⌘Q` 退出时，应用会提示保存未保存的修改，也可不保存或取消退出。
- `⌘1` 编辑，`⌘2` 同屏预览，`⌘3` 仅预览。
- 顶部工具栏可插入 1–6 级标题、字号、表格、列表、链接、图片、引用和代码。
- `⇧⌘H` 查看操作记录。记录保存在本机的 `~/Library/Application Support/Markdown++/History.json`，包含时间、操作、文件名和已保存文件的路径。
- 在应用菜单中选择「设为默认 Markdown 应用…」，按 macOS 提示确认。也可以在 Finder 中对 Markdown 文件选择「显示简介」，在「打开方式」选择 Markdown++ 后点「全部更改…」。

### 设置

点击编辑器右上角的齿轮，或按 `⌘,` 打开设置。修改后点击「应用」。

- 操作记录默认保留 100 条，可设为 100–9999 条。
- 失焦自动保存默认关闭。开启后，已有文件在文档窗口失去焦点时保存未保存的修改。新文件首次按 `⌘S` 选择保存位置。每次成功手动保存或自动保存会添加一条相应的操作记录。
- 默认保存文件夹可选。设定后，新文件首次按 `⌘S` 会从该文件夹打开保存对话框，仍可修改文件名或位置。清除后，使用 macOS 的常规保存对话框。
- 文件打开模式可选择源码编辑、仅预览或同屏预览，默认同屏预览。
- 主题可选择黑色、白色或跟随系统，默认跟随系统，应用后编辑器和预览会立即更新。

### 下载

从 [GitHub Releases](https://github.com/YzxUpUp/markdown-plus-plus/releases/latest) 下载 macOS 通用 ZIP。解压后把 Markdown++ 拖到「应用程序」。压缩包包含 Apple Silicon 和 Intel 架构，最低系统要求为 macOS 13。

下载包使用临时签名，未经 Apple 公证。首次启动时 macOS 可能提示无法验证开发者。详情见 [Apple 支持](https://support.apple.com/102445)。

### 构建

安装 Xcode Command Line Tools 后运行 `./build.sh`，在项目的 `build` 目录生成应用。脚本也接受一个以 `.app` 结尾的绝对路径作为安装目标。应用包含 Apple Silicon 和 Intel 架构，构建目标为 macOS 13 及以上。

预览使用随应用打包的 markdown-it 15.0.3，MIT 许可证见 [markdown-it-LICENSE.txt](https://github.com/YzxUpUp/markdown-plus-plus/blob/main/Resources/Preview/markdown-it-LICENSE.txt)。


## English

Markdown++ is a native macOS editor for creating, opening, editing, and saving Markdown files. It opens documents in split view by default, with the source on the left and a live preview on the right. You can also switch to source-only or preview-only mode.

- Press `⌘N` to create a document, `⌘O` to open one, `⌘S` to save, or `⇧⌘S` to save as.
- When you press `⌘Q` with unsaved changes, you can save, discard your changes, or cancel quitting.
- Press `⌘1` for source editing, `⌘2` for split view, or `⌘3` for preview only.
- Use the toolbar to insert headings (levels 1–6), font sizes, tables, lists, links, images, quotes, and code.
- Press `⇧⌘H` to view your activity history. It is stored locally in `~/Library/Application Support/Markdown++/History.json` and records timestamps, actions, file names, and paths for saved files.
- To set Markdown++ as the default app for Markdown files, choose 「设为默认 Markdown 应用…」 in the Markdown++ menu and follow the macOS prompt. You can also select a Markdown file in Finder, choose **Get Info**, select Markdown++ under **Open with**, and click **Change All**.

### Settings

Click the gear in the upper-right corner of the editor, or press `⌘,`. Click 「应用」 (Apply) to save your settings.

- The activity history retains 100 entries by default. You can set a limit from 100 to 9,999.
- Autosave on focus loss is off by default. When enabled, changes to existing files are saved when the document window loses focus. Press `⌘S` to choose where to save a new file for the first time. Each successful manual save or autosave adds one history entry.
- You can set a default save folder. The first `⌘S` on a new document opens the save dialog in that folder, where you can still choose a file name or a different location. Clear the setting to restore the standard macOS save dialog.
- Choose source editing, preview only, or split view as the default opening mode. Split view is the default.
- Choose Dark, Light, or Follow System. Follow System is the default. Changes apply to the editor and preview immediately.

### Download

Download the universal macOS ZIP from [GitHub Releases](https://github.com/YzxUpUp/markdown-plus-plus/releases/latest). Extract it and drag Markdown++ to your Applications folder. The archive includes Apple silicon and Intel builds and requires macOS 13 or later.

The app is ad hoc signed and has not been notarized by Apple. macOS may display a warning the first time you open it. See [Apple Support](https://support.apple.com/102445).

### Build

Install the Xcode Command Line Tools, then run `./build.sh`. The app is built in the project's `build` directory. The script also accepts an absolute path ending in `.app` as its output destination. It builds both Apple silicon and Intel slices with a macOS 13 deployment target.

The preview uses the bundled markdown-it 15.0.3 library. See its [MIT license](https://github.com/YzxUpUp/markdown-plus-plus/blob/main/Resources/Preview/markdown-it-LICENSE.txt).
