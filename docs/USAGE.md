# 使用说明

[返回首页](../README.md)

支持 Linux、macOS；Windows 可使用 WSL。项目开源于 [tingfeng347/windvim](https://github.com/tingfeng347/windvim)，可以克隆仓库、下载 GitHub 源码包，或使用本地源码安装。**不依赖 dotfiles 仓库。**

## 准备依赖

直接运行 `./install.sh`，安装器会检查并补齐 **Neovim ≥ 0.11.2（LuaJIT）**、Git、`rsync`、`curl`、`ripgrep`、`fd`、C 编译器、`make`、`unzip`、`tar` 和 `gzip`。已有合适的 Neovim 会复用。安装系统包时，root 直接调用包管理器；普通 Linux 用户通过 sudo 安装，可能需要输入密码。配置和启动器仍安装到运行脚本的用户目录，请以实际使用 WindVim 的用户执行 `./install.sh`。

| 系统 | 自动安装方式 |
| --- | --- |
| Ubuntu / Debian 及其衍生版、对应 WSL | apt-get 安装缺少的工具；Neovim 使用官方 v0.11.5 Linux 二进制，支持 x86_64 / arm64、兼容的 glibc 环境 |
| Arch / Manjaro | pacman 安装；为避免部分升级，会执行 `-Syu`，同步升级系统包 |
| Fedora / RHEL 系 | dnf，旧系统回退 yum；包需在已启用仓库中可用 |
| openSUSE | zypper |
| Alpine | apk；使用系统 Neovim 包，避免运行依赖 glibc 的官方二进制 |
| macOS | Homebrew；需要先按 [Homebrew 官方说明](https://brew.sh) 安装 brew，以普通用户运行安装器 |

Ubuntu / Debian 的系统 Neovim 可能低于最低要求，因此不会直接依赖 `apt install neovim`。安装器从 [Neovim 官方发布页](https://github.com/neovim/neovim/releases/tag/v0.11.5) 下载指定架构的压缩包，通过固定 SHA-256 校验后，安装到 `${XDG_DATA_HOME:-$HOME/.local/share}/windvim-tools/neovim`。`windvim` 启动器会自动选择该版本，无需替换 `/usr/bin/nvim` 或额外配置 Neovim 的 PATH。下载失败、校验不符或二进制无法运行时会停止，修复网络或环境后重新运行即可。

其他平台使用仓库的 Neovim，安装后会验证最低版本与 LuaJIT；旧发行版可能需要自行启用合适的软件源或安装新版，再通过 `NVIM_BIN=/absolute/path/to/nvim ./install.sh` 指定。显式设置的 `NVIM_BIN` 无效时会报错，不自动替换。Debian 的 `fdfind` 会通过启动器目录中的 `fd` 软链提供命令；已有文件保留。

macOS 缺少 C 编译器时会触发 `xcode-select --install`，完成系统安装窗口后重新运行脚本。其他平台或希望自行管理依赖时，可手动安装后运行 `./install.sh --no-deps`；该选项只检查 Neovim、Git、`rsync`，其余工具需自行准备。

以下工具按需要另行安装：Tree-sitter CLI（部分语法解析器需要）、Nerd Font v3+（安装到运行终端的电脑，用于图标）、`lazygit`、Node.js / npm（部分语言工具和 Copilot 使用）。AI CLI 需各自安装与登录。完整要求参考 [LazyVim 官方要求](https://www.lazyvim.org/#%EF%B8%8F-requirements)，Git 需 ≥ 2.19。

## 安装配置

从 GitHub 克隆：

```bash
git clone https://github.com/tingfeng347/windvim.git
cd windvim
./install.sh
```

也可以直接下载 GitHub 源码包：

```bash
curl -fL https://github.com/tingfeng347/windvim/archive/refs/heads/main.tar.gz -o windvim.tar.gz
tar -xzf windvim.tar.gz
cd windvim-main
./install.sh
```

压缩包安装的目录没有 Git 元数据，后续更新请重新下载源码包并运行 `./install.sh --force`。从 Git 克隆的目录可以通过 `git pull --ff-only` 更新。

已有本地源码或解压目录时，进入该目录安装并启动：

```bash
cd windvim
./install.sh

# 安装后打开新终端；首次启动下载插件，需要能访问 GitHub
windvim
# 启动器会选择可用的 Neovim，并设置 NVIM_APPNAME=windvim
```

安装器会补齐依赖、创建启动器，并自动将其目录加入当前登录 Shell 的 PATH 配置，支持 Bash、Zsh、Fish。打开新终端后直接执行 `windvim`；已有终端可先使用 `~/.local/bin/windvim`。已有目标会在安装系统包前停止，使用 `./install.sh --force` 才会先备份再替换配置。

```bash
# 指定独立配置名，不创建启动器
./install.sh --appname my-windvim --no-launcher
# 启动时执行安装结束后显示的 Start 命令

# 依赖已手动准备好，不自动安装系统包或下载 Neovim
./install.sh --no-deps

# 使用旧的 lazyvim 名称（已有配置时需要 --force，并生成备份）
./install.sh --appname lazyvim --force --no-launcher
# 同样执行输出的 Start 命令，其中已设置 NVIM_APPNAME=lazyvim
```

支持 `XDG_CONFIG_HOME`、`XDG_DATA_HOME`、`WINDVIM_BIN_DIR`（默认 `~/.local/bin`）、`NVIM_BIN`。配置目录默认 `~/.config/windvim`；数据、缓存和状态使用 Neovim 对应的 XDG 目录下的 `windvim` 子目录。若安装时设置了 `NVIM_BIN`，使用启动器时也需保留该变量。

## 安装后启动

安装完成后打开新终端，无需回到源码目录，在任意目录运行 `windvim` 即可打开首页。进入自己的项目目录再启动，可让文件树、文件查找和 AI CLI 使用该项目作为工作目录：

```bash
cd /path/to/your/project
windvim
# 或直接打开项目中的文件
windvim README.md
```

默认自动配置 PATH，无需手动编辑环境变量。Bash 写入 `~/.bashrc` 和当前使用的登录配置（优先 `.bash_profile`、其次 `.bash_login`、否则 `.profile`）；Zsh 写入 `${ZDOTDIR:-$HOME}/.zshrc` 与 `.zprofile`；Fish 写入 `${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/windvim-path.fish`。已有文件修改前会生成备份，重复安装不会重复写入相同配置。

脚本无法修改父终端的环境，安装后需要打开新终端；若暂时不重开，可用 `~/.local/bin/windvim`。`--no-path` 跳过 PATH 设置，`--no-launcher` 同时跳过启动器和 PATH 设置。其他 Shell 会显示手动设置提示。卸载时保留 PATH 配置，便于该目录中的其他命令和后续重新安装继续使用。

使用 `--no-launcher` 安装时，按照安装器输出的 `Start:` 命令启动；系统 Neovim 已满足要求时为 `NVIM_APPNAME=windvim nvim`，下载版本则使用工具目录中的 Neovim 绝对路径。自定义配置名会自动体现在输出中。直接运行 `nvim` 会使用它自己的默认配置。若安装时设置了自定义 XDG 路径，启动时继续使用相同环境变量；设置了 `WINDVIM_BIN_DIR` 则使用对应目录中的启动器。

首次启动先显示不依赖插件的彩色中文动态首页，后台自动安装插件，显示就绪数量与当前任务。成功后在同一窗口加载完整 WindVim，再次启动直接进入完整配置；`windvim 文件名` 的文件参数会保留。首页按 `f` 查找文件、`n` 新建文件、`q` 退出。进入编辑界面后按空格再按 `e` 打开文件树；按 `Esc` 后输入 `:wq` 并回车，可保存并关闭当前窗口。

### 首次启动停在空白界面

![首次安装的中文动态首页](screenshots/first-install.png)

首次启动先画出 WindVim 中文首页，再由独立的后台 Neovim 进程下载插件管理器、插件并运行构建，下载期间动画和按键仍可响应。自动尝试最多 3 轮，已完成的下载保留，失败的构建会单独记录并补跑；成功后当前窗口自动切换到完整 WindVim。外部语言服务器、Mason 工具与 AI CLI 的安装/登录仍遵循各自配置。

仍然失败时首页显示原因，按 `l` 查看实时日志（日志窗口按 `q` 返回），网络恢复后按 `r` 继续安装，按 `q` 退出。失败不会写入完成标记。小窗口显示精简文字标识，`WINDVIM_ANIMATION=0` 可关闭动画。无界面的 `--headless` 命令保留同步安装语义，不显示首页。

首次下载插件管理器默认 120 秒超时，可调整并查看日志（自定义应用名时替换路径中的 `windvim`）：

```bash
WINDVIM_BOOTSTRAP_TIMEOUT=30 windvim
cat "${XDG_STATE_HOME:-$HOME/.local/state}/windvim/install.log"
# 插件管理器下载失败的详细记录
cat "${XDG_STATE_HOME:-$HOME/.local/state}/windvim/bootstrap.log"
```

下载使用独立临时目录，不完整的旧插件管理器目录会在成功下载后先备份再替换。已有旧版配置时，退出 WindVim 后在源码目录执行 `git pull --ff-only && ./install.sh --force` 更新配置，再运行 `windvim`；安装器会备份配置并保留插件数据。

已经安装插件管理器后若仍然空白，可在 Ubuntu 终端中收集启动日志：

```bash
WINDVIM_BOOTSTRAP_TIMEOUT=20 timeout 30s windvim --headless -V1/tmp/windvim-startup.log '+qa!'
tail -n 60 /tmp/windvim-startup.log
```

这项诊断不会删除配置或插件；首次启动仍可能触发正常的插件安装。`timeout` 返回 124 表示达到诊断的等待上限，不代表已经定位到某个具体插件。分享日志前请移除令牌、代理凭据等敏感信息。

### 首次安装报 `lazy/manage/lock.lua:28: assertion failed!`

旧版首次下载逻辑曾使用 `--single-branch --branch=stable`。`stable` 是标签，这种克隆方式没有默认分支引用，导致 lazy.nvim 在保存锁文件时无法确定分支。新版恢复[官方克隆方式](https://lazy.folke.io/installation)，并显式配置 lazy.nvim 的 `main` 分支，兼容已经创建的标签克隆目录；后续 `:Lazy update` 会补齐缺失的分支引用。

退出 WindVim 后，在源码目录执行以下命令。安装器会备份并更新配置，同时恢复项目中的有效锁文件，无需删除其他插件数据：

```bash
git pull --ff-only
./install.sh --force
windvim
```

## 启动页动画

启动页以薄荷青、天蓝、鸢尾紫到柔粉过渡的 W 为中心，保留明暗层次，暖金色粒子作点缀，风环与粒子循环流动。动画只更新标识区域，不改动菜单、光标或文件内容；打开其他面板、离开启动页或终端失焦时暂停，小窗口使用静态文字标识。

使用静态启动页：

```bash
WINDVIM_ANIMATION=0 windvim
# 或 WINDVIM_ANIMATION=0 NVIM_APPNAME=windvim nvim
```

设置 `NO_COLOR` 时也会停止动画。动画使用原生终端字符，不需要终端图像协议或额外插件。

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
| `<Space>tt` | 切换底部终端（项目根目录，原 `<Space>ft`） |
| `<Space>tT` | 切换底部终端（当前工作目录，原 `<Space>fT`） |
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

先退出 WindVim，再在项目源码目录卸载：

```bash
./uninstall.sh
# 同时删除插件数据、缓存和状态，仍保留配置备份
./uninstall.sh --purge
# 卸载自定义配置名，保留启动器
./uninstall.sh --appname my-windvim --no-launcher
```

默认将配置移为同目录下的 `windvim.backup.<时间戳>.<进程号>`，匹配安装器生成内容和应用名的启动器也会备份；其他启动器保留。重复运行可直接退出，无需安装 Neovim。

`--purge` 删除指定应用的插件、缓存与语言状态，默认路径是 `~/.local/share/windvim`、`~/.cache/windvim`、`~/.local/state/windvim`。脚本支持 `XDG_CONFIG_HOME`、`XDG_DATA_HOME`、`XDG_CACHE_HOME`、`XDG_STATE_HOME` 和 `WINDVIM_BIN_DIR`；配置备份和其他应用保留。通过符号链接共享的数据只移除链接，不删除链接指向的目录。

卸载不会移除系统包、`fd` 兼容软链或 `${XDG_DATA_HOME:-$HOME/.local/share}/windvim-tools` 中下载的 Neovim，供其他配置名和重新安装复用。确认不再使用后，可自行删除工具目录。
