# WindVim 独立项目

规格：有效；实现：代码完成；验收：首次安装本地回归、完整 UI 切换和全新网络下载通过（2026-10-23）；2026-10-22 结果保留为历史。

## 范围与决定

- 项目位于 `self_project/windvim`，源码从 dotfiles 复制，保留相关 Git 历史。
- 按后续用户授权公开发布并推送到 GitHub；早期仅本地的限制已被后续指令替代。
- 按用户后续明确要求：dotfiles 的 LazyVim 模块与安装入口原样保留；WindVim 是独立副本，本机 `~/.config/lazyvim` 也保留。
- 项目根目录保留 Neovim 常规配置结构，独立安装器默认复制到 `stdpath(config)` 对应的 `windvim` 目录，创建 `~/.local/bin/windvim`。
- 安装已有目标默认拒绝；显式 `--force` 先备份再覆盖。自定义 appname 和 XDG 路径可用；不自动覆盖 nvim / lazyvim。
- README 含可用的本地分发安装步骤、真实 UI 截图、SVG 标志和状态徽标、LazyVim 链接与许可证来源。
- 安装器按平台补齐系统依赖；不管理 AI 凭据。首次启动先显示原生中文动态首页，再后台安装插件。

## 任务与验收

| 行为 | 验证入口 | 状态 |
| --- | --- | --- |
| 独立安装与隔离 | 临时 XDG 目录，运行真实 installer 和 launcher | 通过 |
| 拒绝覆盖与显式备份 | 已有配置及启动器演练，备份内容核对 | 通过 |
| 自定义 appname、路径与参数转发 | 安装行为测试 | 通过 |
| Lua / JSON 可读取 | scripts/check.lua | 通过 |
| 实际 UI 汉化及中英切换 | 隔离安装 + 现有插件缓存 + 真实嵌入 UI | 通过 |
| 截图、徽标、引用及本地链接 | 图片人工查看、Markdown 路径检查 | 通过 |
| dotfiles 原配置与入口保留 | dotfiles 工作区无差异 + 原文件检查 | 通过 |

## 验证边界

UI 集成可以复用本机已有且与锁文件对应的插件缓存；此项不代替全新网络下载验证。不同系统的依赖安装与 AI 服务登录由用户环境提供。审查以本次新项目全部文件及 dotfiles 工作区相对 `5cbcfc3` 的差异为范围，含未跟踪文件。

## 实际结果（2026-10-22）

- 独立仓库通过 Git subtree split 复制相关配置历史；dotfiles 相对 `5cbcfc3` 无任何工作区差异，原 LazyVim 模块与脚本存在。
- `python3 -m unittest discover -s tests -v`：7 项通过。覆盖路径含空格、既有配置保护、显式备份、既有启动器保护与备份、参数转发、自定义名称、版本拒绝，以及防止安装器移动自身源目录。
- `nvim --clean --headless -i NONE -l scripts/check.lua`：25 个 Lua 文件与 3 个 JSON 文件通过；安装/同步脚本 Bash 语法通过。
- 通过 installer 安装到临时 XDG 目录，复用本机锁定版本插件、parser 和 Mason 缓存，实际附加 Neovim UI 集成测试返回 PASS；本地汉化插件目录明确解析到该独立安装。五张截图导出到 `docs/screenshots/`，逐张查看；SVG 标志已渲染查看，Markdown 本地链接与图片引用均有效。
- 全新 config/data/state/cache 目录的在线 bootstrap 演练：大部分插件完成下载；`friendly-snippets` 在 GitHub checkout 时出现 TLS EOF，150 秒后测试超时。日志位于 Git 忽略的 `.tests/clean-install.log`。不将此项标记为首次全新下载通过。
- 按规范与需求两个视角自审本项目新改动及未跟踪文件，未使用独立代理。生产配置源码与原 dotfiles 对应文件一致，除新增独立安装/文档/测试能力外，不改变编辑器定制行为。

## 2026-10-23 · 首次启动安装流程

规格：有效；实现：已完成；验收：46 项回归、已有缓存的完整 UI 集成，以及全新网络安装均通过。

- `init.lua` 根据 app 专属完成记录和插件目录判断是否首次安装；headless 保持原有同步行为。
- 原生首页复用现有彩色 W 和风环动效，不依赖 lazy.nvim / Snacks。后台进程使用同一 Neovim、应用名与 XDG 路径，主窗口显示插件数、当前任务、失败原因及日志入口。
- 工作进程完成真实安装、构建和 spec 检查后才报告成功；失败的构建持久记录，最多 3 轮自动尝试，失败后保留可操作页面。`r` 重新尝试，`l` 查看日志，`q` 退出并停止安装进程。
- 成功后在原进程加载完整配置和 Snacks 首页；保留打开文件的参数。已有安装无完成记录时补验一次，不删除插件数据。小窗口保留文字状态与按键，关闭动画和失焦暂停沿用现有约定。

验收入口：`python3 -m unittest discover -s tests -v`（含真实 lazy.nvim、本地 Git 的失败重试与同进程切换）；`scripts/check.lua`。UI 证据保存于 Git 忽略的 `.tests/first-run-ui/`；42 插件副本的完整首页切换已通过。全新 config/data/state/cache 通过真实 GitHub 下载 42/42 插件，1 轮完成，原进程自动打开中文动态首页；记录位于 `.tests/first-run-network/`。Neovim 0.12.6 与官方 0.11.5 分别验证，未在真实 Ubuntu VM 或 macOS 上运行。
