<p align="center">
  <img src="docs/assets/windvim.svg" alt="WindVim — 随风而行，专注于代码" width="600" />
</p>

<p align="center">
  <strong>熟悉的 LazyVim，更顺手的中文开发环境。</strong><br />
  A personal LazyVim setup with switchable Chinese UI and AI CLI panels.
</p>

<p align="center">
  <a href="https://www.lazyvim.org/"><img src="https://img.shields.io/badge/Built_with-LazyVim-89b4fa?style=flat-square" alt="Built with LazyVim" /></a>
  <a href="https://neovim.io/"><img src="https://img.shields.io/badge/Neovim-%E2%89%A50.11.2-a6e3a1?style=flat-square&logo=neovim" alt="Neovim ≥ 0.11.2" /></a>
  <img src="https://img.shields.io/badge/UI-%E4%B8%AD%E6%96%87_%2F_English-94e2d5?style=flat-square" alt="中文 / English" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache--2.0-cba6f7?style=flat-square" alt="Apache-2.0 License" /></a>
</p>

WindVim 是基于 **[LazyVim](https://github.com/LazyVim/LazyVim)** 和 [LazyVim Starter](https://github.com/LazyVim/starter) 的个人定制配置，从 [dotfiles](https://github.com/tingfeng347/dotfiles) 复制而来，原 dotfiles 的 LazyVim 模块仍保留。保留 LazyVim 的插件生态与快捷键习惯，加入可插拔汉化、WindVim 启动页、统一透明主题和 AI CLI 面板布局。

## 界面预览

以下图片由实际 Neovim UI 网格捕获，使用仓库锁定的插件版本；终端背景与字体会影响最终效果。

![WindVim 中文启动页](docs/screenshots/dashboard-zh.png)

<table>
  <tr>
    <td><img src="docs/screenshots/which-key-zh.png" alt="中文快捷键菜单" /><br /><strong>中文快捷键菜单</strong> · 原有键位与动作保留</td>
    <td><img src="docs/screenshots/picker-zh.png" alt="中文文件选择器" /><br /><strong>文件选择器</strong> · 中文标题与路径原文</td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/lazy-zh.png" alt="中文 Lazy 插件管理器" /><br /><strong>插件管理</strong> · 汉化常用操作与帮助</td>
    <td><img src="docs/screenshots/dashboard-en.png" alt="英文启动页" /><br /><strong>运行时切换英文</strong> · 自动保存语言选择</td>
  </tr>
</table>

## 有什么不同

- **常用界面中文 / English 切换**：which-key、lazy.nvim、Snacks Picker / Explorer 和启动页。`<Space>uH` 随时切换；不改动文件内容、命令、路径或插件源码。未收录的文字显示原文。
- **AI CLI 侧栏**：使用 LazyVim 的 Sidekick Extra，在右侧按列组织终端，每列最多三个面板。复用 `<Space>aa` 等上游键位。
- **浮动终端**：`<Space>tp` 打开居中的圆角 shell，独立于默认底部终端。
- **一致的视觉风格**：Catppuccin、透明背景、Bufferline、Dropbar 与 Markdown 渲染配置；WindVim 启动页针对窄窗口与关闭面板后的游标恢复做了处理。
- **独立安装**：默认使用 `NVIM_APPNAME=windvim`，配置、插件、缓存、状态与现有 `nvim` / `lazyvim` 分开。

## 安装

支持 Linux、macOS；Windows 可使用 WSL。当前项目仅在本地维护，可分享整个目录或源码压缩包供其他人安装。**不依赖 dotfiles 仓库。**

维护者可生成分享用的源码包（包含截图，接收者无需 Git 历史）：

```bash
mkdir -p .dist
git archive --format=tar.gz --prefix=windvim/ HEAD -o .dist/windvim.tar.gz
# 接收者：tar -xzf windvim.tar.gz，然后按下面步骤安装
```

### 1. 准备依赖

- **Neovim ≥ 0.11.2，带 LuaJIT**，Git ≥ 2.19，`rsync`、`curl`、`ripgrep`、`fd`。
- Tree-sitter CLI 与 C 编译器，用于语法解析器；Nerd Font v3+ 用于图标。
- 可选：`lazygit`；Node.js / npm 用于部分语言工具与 Copilot；AI CLI 需另行安装和登录。

要求参考 [LazyVim 官方要求](https://www.lazyvim.org/#%EF%B8%8F-requirements)。Ubuntu 22.04 / 24.04 的系统 Neovim 版本不足，请先从 [Neovim 官方发布页](https://github.com/neovim/neovim/releases) 安装合适版本。Ubuntu 的 `fd-find` 可通过 `~/.local/bin/fd` 软链提供 `fd` 命令。

```bash
# macOS（已安装 Homebrew）
brew install neovim git rsync ripgrep fd curl tree-sitter-cli
# C 编译器由 Xcode Command Line Tools 提供：xcode-select --install

# Arch Linux
sudo pacman -S neovim git rsync ripgrep fd curl tree-sitter-cli base-devel
```

### 2. 安装配置

获得项目目录或解压源码包后：

```bash
cd windvim
./install.sh

# 首次启动自动下载插件，需要能稳定访问 GitHub 的网络
~/.local/bin/windvim
# 等价于：NVIM_APPNAME=windvim nvim
```

将 `~/.local/bin` 加入 PATH 后可直接执行 `windvim`。安装器只复制配置和创建启动器，不使用 sudo、不自动安装系统依赖；已有目标会停止，使用 `./install.sh --force` 才会先备份再替换。

```bash
# 指定独立配置名，不创建启动器
./install.sh --appname my-windvim --no-launcher
NVIM_APPNAME=my-windvim nvim

# 使用旧的 lazyvim 名称（已有配置时需要 --force，并生成备份）
./install.sh --appname lazyvim --force --no-launcher
NVIM_APPNAME=lazyvim nvim
```

支持 `XDG_CONFIG_HOME`、`WINDVIM_BIN_DIR`（默认 `~/.local/bin`）、`NVIM_BIN`。配置目录默认 `~/.config/windvim`；数据、缓存和状态使用 Neovim 对应的 XDG 目录下的 `windvim` 子目录。

### 3. 检查环境与 AI 功能

启动后运行 `:LazyHealth` 和 `:checkhealth` 查看依赖情况。插件版本由 `lazy-lock.json` 记录；需要恢复锁定版本时运行 `:Lazy restore`。

Copilot 需要单独通过 `:Copilot auth` 登录。Sidekick 的 Codex、Claude 等 CLI 需各自安装并登录，查看 `:checkhealth sidekick`。未配置 AI 账号时，文件编辑、导航和汉化功能仍可使用。当前 Avante 声明只在检测到 Copilot 凭据时启用；AI 服务与其订阅不包含在项目中。

## 常用操作

Leader 键是 **空格**。大多数行为沿用 [LazyVim 默认快捷键](https://www.lazyvim.org/keymaps)。

| 快捷键 / 命令 | 功能 |
| --- | --- |
| `<Space>uH` | 切换中文 / English，并记住选择 |
| `:LazyVimLanguage zh_CN` / `en` | 显式设置界面语言 |
| `<Space>ff` / `<Space>sg` | 查找文件 / 搜索文本 |
| `<Space>e` | 文件浏览器 |
| `<Space>tp` | 居中浮动终端 |
| `<Space>aa` / `<Space>as` | 切换 / 选择 Sidekick CLI |
| `<Space>ap` | Sidekick 提示词 |
| `:Lazy` / `:LazyExtras` | 插件管理 / LazyVim Extras |

临时英文启动：`LAZYVIM_LANGUAGE=en windvim`。完全禁用汉化：将 `lua/plugins/i18n.lua` 中的 `enabled` 设为 `false`，重新安装配置并重启。详细覆盖范围与自定义词典见 [汉化插件说明](local-plugins/lazyvim-i18n.nvim/README.md)。

## 更新、定制与卸载

编辑项目目录中的 `lua/config/`、`lua/plugins/` 或本地汉化插件，再运行 `./install.sh --force` 部署。若项目来自 Git 克隆，可先 `git pull --ff-only` 获取配置更新。安装目录中的临时修改会随备份一起保留，建议将长期修改维护在自己的项目副本中。

```bash
# 显式更新插件，会改动安装目录的锁文件
./scripts/sync.sh
# 自定义配置名：NVIM_APPNAME=my-windvim ./scripts/sync.sh
```

`--force` 将旧配置保存为配置目录旁的 `windvim.backup.<时间戳>.<进程号>`，旧启动器也单独备份。恢复时移走新配置，把备份目录改回原名即可；数据目录保留。

卸载默认安装的配置与启动器：

```bash
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/windvim"
rm -f ~/.local/bin/windvim
```

插件、缓存与语言状态可按需单独删除：`~/.local/share/windvim`、`~/.cache/windvim`、`~/.local/state/windvim`（若设置 XDG 变量，请使用相应路径）。旧的 `nvim` / `lazyvim` 配置和备份保留。

## 测试与截图复现

```bash
nvim --clean --headless -i NONE -l scripts/check.lua
python3 -m unittest discover -s tests -v

# 安装并启动过 WindVim 后，测试实际 UI；需要 uv 和可显示中文的字体
uv run --with pynvim --with pillow python local-plugins/lazyvim-i18n.nvim/tests/run.py

# 导出本 README 使用的真实界面截图
I18N_SCREENSHOT_DIR="$PWD/docs/screenshots" \
  uv run --with pynvim --with pillow python local-plugins/lazyvim-i18n.nvim/tests/run.py
```

可用 `I18N_TEST_FONT=/path/to/font.ttf` 指定字体。测试会开独立 Neovim 子进程，使用临时语言状态，验证面板汉化、中英切换、窄屏布局与卸载恢复，不修改生产语言选择。

## 致谢与许可证

核心编辑体验来自 **[LazyVim](https://github.com/LazyVim/LazyVim)**，配置起点来自 **[LazyVim Starter](https://github.com/LazyVim/starter)**。感谢 [folke](https://github.com/folke) 及 [lazy.nvim](https://github.com/folke/lazy.nvim)、[Snacks](https://github.com/folke/snacks.nvim)、[which-key](https://github.com/folke/which-key.nvim)、[Sidekick](https://github.com/folke/sidekick.nvim) 与各插件作者。

WindVim 是独立的社区定制配置。保留 Starter 的 [Apache-2.0 许可证](LICENSE)，本项目新增内容沿用该许可证，来源和修改说明见 [NOTICE](NOTICE)。各依赖遵循各自许可证。
