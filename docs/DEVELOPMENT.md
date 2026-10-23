# 开发与分发

[返回首页](../README.md)

## 本地开发

在项目根目录执行以下命令。配置修改先在独立的测试配置中验证，再按需部署；项目源码和安装目录由安装器复制隔离。

```bash
nvim --clean --headless -i NONE -l scripts/check.lua
python3 -m unittest discover -s tests -v

# 安装并启动过 WindVim 后，测试实际 UI；需要 uv 和可显示中文的字体
uv run --with pynvim --with pillow python local-plugins/lazyvim-i18n.nvim/tests/run.py

# 重新录制 README 和图库的项目演示
uv run --with pynvim --with pillow python scripts/screenshots.py

# 同时录制右侧 Claude Code / Codex 双面板（需要已安装并配置两个 CLI）
uv run --with pynvim --with pillow python scripts/screenshots.py --ai
```

可用 `I18N_TEST_FONT=/path/to/font.ttf` 指定字体。测试会开独立 Neovim 子进程，使用临时语言状态，验证面板汉化、中英切换、窄屏布局与卸载恢复，不修改生产语言选择。

`tests/test_dependencies.py` 使用模拟包管理器和本地下载样本验证平台识别、权限选择与校验失败；安装器回归测试使用 `--no-deps`。运行测试不会安装或升级宿主机的系统包。

`tests/test_startup.py` 使用真实 Neovim 和隔离的 XDG 目录，通过伪终端模拟首次下载卡住、超时、中断和重试，确认等待期间能看到文字。Git 使用本地替身，不会下载真实插件；可设置 `NVIM_BIN` 指定需要验证的 Neovim 版本。

`tests/test_lazy_lock.py` 使用真实 lazy.nvim 的锁文件写入和更新流程，搭配本地 Git 仓库，验证首次克隆及旧标签克隆的兼容性。默认读取已安装的 `windvim`、`lazyvim` 或 `nvim` 插件缓存，也可设置 `WINDVIM_TEST_LAZY=/path/to/lazy.nvim`；找不到源码时会跳过这两项测试。所有仓库操作和锁文件写入都在临时目录完成，不访问网络、不更新原插件缓存。

## 源码分发

用户可通过 [GitHub 公开仓库](https://github.com/tingfeng347/windvim) 克隆或下载源码包安装。提交改动后，也可以生成包含文档和截图的分享包：

```bash
mkdir -p .dist
git archive --format=tar.gz --prefix=windvim/ HEAD -o .dist/windvim.tar.gz
```

接收者解压后按[使用说明](USAGE.md)安装，无需 dotfiles 或原仓库的 Git 历史。

## GitHub 发布

公开仓库：[tingfeng347/windvim](https://github.com/tingfeng347/windvim)，默认分支 `main`。维护者提交并验证改动后推送：

```bash
git push -u origin main
```

README 和使用说明提供此仓库的克隆与源码包安装命令；改用其他账号或仓库名时，一并修改文档中的下载地址。

若首次推送含动图的历史出现 `RPC failed; HTTP 408`，可仅为本仓库增大 HTTP 请求缓冲区后重试；本次发布使用此设置推送成功：

```bash
git config --local http.postBuffer 52428800
git push
```

## 来源与目录

WindVim 从 [dotfiles](https://github.com/tingfeng347/dotfiles) 的 LazyVim 模块复制，保留相关 Git 历史。原 dotfiles 模块和本机已安装配置独立保留；修改 WindVim 项目不会自动同步它们。

- `lua/config/`：通用 Neovim 设置。
- `lua/plugins/`：主题、启动页、AI 面板和快捷键定制。
- `local-plugins/lazyvim-i18n.nvim/`：可插拔的常用界面汉化层。
- `docs/assets/windvim.svg`：项目图标，W 字形与风线组成。
- `spec/`：需求、方案和验收记录。

`lua/windvim/logo.lua` 使用小型深度缓冲绘制管状 W、风环和粒子，每 120ms 更新一次字符覆盖层；菜单缓冲区和光标保持稳定。动画在后台、窄窗口或低高度终端暂停，`WINDVIM_ANIMATION=0` 可保持静态。

演示素材使用 `scripts/screenshots.py` / `scripts/screenshots.lua` 录制，复用 UI 网格捕获器。脚本创建独立 XDG 配置与临时项目克隆，先拍摄不带目录树的独立启动页，再打开 WindVim 自身项目的目录树，拍摄源码编辑、文件快捷键、搜索预览和插件管理；不会部署到本机配置。默认使用 144 × 38 的界面尺寸，录制期间临时关闭消息浮层，导出图片放在 `docs/screenshots/`。启动页动图、快捷键菜单、搜索预览和插件管理均录制中英文版本，分别供 `README.md` / `README.en.md` 与双语图库使用。

运行前需要 WindVim 已安装插件。默认读取本机 WindVim 的数据目录，也可通过 `WINDVIM_DEMO_DATA=/path/to/data` 指定兼容的插件缓存。演示项目取自本地 Git 的 HEAD；需要展示新的源码时先提交它。渲染器继续支持 `I18N_TEST_FONT` 指定字体。

汉化集成测试的默认输出保留在 `.tests/i18n/`，与文档演示分开。若单独向测试脚本设置 `WINDVIM_CAPTURE_ANIMATION=1`，也能录制测试场景中的启动页动图。

`scripts/screenshots.py --ai` 会额外运行 `scripts/ai-workspace.lua`，在独立的临时配置和项目中启动真实的 Claude Code 与 Codex，通过 Sidekick 在右侧上下堆叠；录制其待输入界面，不向 AI 提交任务。AI 工作区使用 180 × 50 的界面尺寸，中英文截图分别输出到 `docs/screenshots/ai-workspace-zh.png` 与 `ai-workspace-en.png`。只重拍 AI 工作区可使用 `--ai-only`。
