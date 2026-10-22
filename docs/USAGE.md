# 使用说明

[返回首页](../README.md)

支持 Linux、macOS；Windows 可使用 WSL。当前项目仅在本地维护，可分享整个目录或源码压缩包供其他人安装。**不依赖 dotfiles 仓库。**

## 准备依赖

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

## 安装配置

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

## 环境检查与 AI 功能

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

临时英文启动：`LAZYVIM_LANGUAGE=en windvim`。完全禁用汉化：将 `lua/plugins/i18n.lua` 中的 `enabled` 设为 `false`，重新安装配置并重启。详细覆盖范围与自定义词典见 [汉化插件说明](../local-plugins/lazyvim-i18n.nvim/README.md)。

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
