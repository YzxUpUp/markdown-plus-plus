# Markdown++

Markdown++ 是一款原生 macOS Markdown 编辑器，支持新建、打开、保存和另存文件。默认左侧编辑源码，右侧实时预览，也可以切换到单独的编辑或预览模式。

- `⌘N` 新建，`⌘O` 打开，`⌘S` 保存，`⇧⌘S` 另存为。
- `⌘Q` 退出时，应用会提示保存未保存的修改，也可不保存或取消退出。
- `⌘1` 编辑，`⌘2` 同屏预览，`⌘3` 仅预览。
- 顶部工具栏可插入 1–6 级标题、字号、表格、列表、链接、图片、引用和代码。
- `⇧⌘H` 查看操作记录。记录保存在本机的 `~/Library/Application Support/Markdown++/History.json`，包含时间、操作、文件名和已保存文件的路径。
- 在应用菜单中选择「设为默认 Markdown 应用…」，按 macOS 提示确认。也可以在 Finder 中对 Markdown 文件选择「显示简介」，在「打开方式」选择 Markdown++ 后点「全部更改…」。

## 设置

点击编辑器右上角的齿轮，或按 `⌘,` 打开设置。修改后点击「应用」。

- 操作记录默认保留 100 条，可设为 100–9999 条。
- 失焦自动保存默认关闭。开启后，已有文件在文档窗口失去焦点时保存未保存的修改。新文件首次按 `⌘S` 选择保存位置。每次成功手动保存或自动保存会添加一条相应的操作记录。
- 默认保存文件夹可选。设定后，新文件首次按 `⌘S` 会从该文件夹打开保存对话框，仍可修改文件名或位置。清除后，使用 macOS 的常规保存对话框。
- 文件打开模式可选择源码编辑、仅预览或同屏预览，默认同屏预览。
- 主题可选择黑色、白色或跟随系统，默认跟随系统，应用后编辑器和预览会立即更新。

## 下载

从 [GitHub Releases](https://github.com/YzxUpUp/markdown-plus-plus/releases/latest) 下载 macOS 通用 ZIP。解压后把 Markdown++ 拖到「应用程序」。压缩包包含 Apple Silicon 和 Intel 架构，最低系统要求为 macOS 13。

下载包使用临时签名，未经 Apple 公证。首次启动时 macOS 可能提示无法验证开发者。详情见 [Apple 支持](https://support.apple.com/102445)。

## 构建

安装 Xcode Command Line Tools 后运行 `./build.sh`，在项目的 `build` 目录生成应用。脚本也接受一个以 `.app` 结尾的绝对路径作为安装目标。应用包含 Apple Silicon 和 Intel 架构，构建目标为 macOS 13 及以上。

预览使用随应用打包的 markdown-it 15.0.3，MIT 许可证见 [markdown-it-LICENSE.txt](Resources/Preview/markdown-it-LICENSE.txt)。
