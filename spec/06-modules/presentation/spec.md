# 项目标识与 README

规格：有效；实现：代码完成；验收：通过（2026-10-22）。

- 仅修改 WindVim 项目。保留本机已安装的 LazyVim / WindVim 配置与 dotfiles 模块。
- 启动页人像替换为 W 与风线组成的专属字符标识；README 使用相同风格的 SVG 小图标。
- 参考 https://github.com/tingfeng347/mactools 的 README：居中图标、标题、徽标，简短介绍与截图、安装、快捷键、文档、许可。
- 详细依赖、安装参数、AI、更新与卸载移入 docs/USAGE.md；截图集移入 docs/GALLERY.md；开发、截图复现与分发移入 docs/DEVELOPMENT.md。
- 使用临时 XDG 路径与已有插件缓存验证实际 UI，重拍演示截图；原安装目录以改动前后文件摘要验证不变。
- 验证 Lua / JSON、Markdown 本地引用及新旧语言启动页；在窄窗口确认图形隐藏后菜单可用。

## 验收结果

- `scripts/check.lua`：25 个 Lua 文件、3 个 JSON 文件读取通过；本地 Markdown 链接和图片路径全部有效，`git diff --check` 通过。
- 通过安装器复制到临时 XDG 路径，复用已安装插件缓存，真实 Neovim UI 集成返回 PASS。140 / 80 列显示新 W 标识；33 列隐藏标识后保留可用菜单。
- 五张演示截图重新导出；中英文启动页、快捷键菜单与 80 / 33 列额外截图已查看。SVG 项目标志已渲染查看。
- 修改前后对 `~/.config/lazyvim`、已有 `~/.config/windvim`（若存在）与 dotfiles 的 LazyVim 模块逐文件 SHA-256 比对一致；未向它们部署。
- README 从 166 行缩减到 57 行。详细使用、图库、开发与分发各有独立文档；保留 LazyVim 引用、徽标及许可证入口。
- 变更自审范围为本轮品牌与文档文件；不改安装器、插件版本或其他功能。全新网络下载限制沿用独立项目验收记录。
