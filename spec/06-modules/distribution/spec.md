# WindVim 独立项目

规格：有效；实现：代码完成；验收：本地行为与 UI 通过，全新网络下载受阻（2026-10-22）。

## 范围与决定

- 项目位于 `self_project/windvim`，源码从 dotfiles 复制，保留相关 Git 历史。
- 仅本地项目；用户明确选择暂不公开，不创建远端、不推送。
- 按用户后续明确要求：dotfiles 的 LazyVim 模块与安装入口原样保留；WindVim 是独立副本，本机 `~/.config/lazyvim` 也保留。
- 项目根目录保留 Neovim 常规配置结构，独立安装器默认复制到 `stdpath(config)` 对应的 `windvim` 目录，创建 `~/.local/bin/windvim`。
- 安装已有目标默认拒绝；显式 `--force` 先备份再覆盖。自定义 appname 和 XDG 路径可用；不自动覆盖 nvim / lazyvim。
- README 含可用的本地分发安装步骤、真实 UI 截图、SVG 标志和状态徽标、LazyVim 链接与许可证来源。
- 安装器不管理系统依赖和 AI 凭据；插件通过 lazy.nvim 首次启动安装。

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
