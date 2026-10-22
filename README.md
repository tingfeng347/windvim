<p align="center">
  <img src="docs/assets/windvim.svg" width="96" height="96" alt="WindVim logo">
</p>

<h1 align="center">WindVim</h1>

<p align="center">
  <strong>基于 LazyVim 的 Neovim 配置 — 中文界面、AI 侧栏与浮动终端</strong>
</p>

<p align="center">
  <a href="https://www.lazyvim.org/"><img src="https://img.shields.io/badge/Built_with-LazyVim-89b4fa?style=flat-square" alt="Built with LazyVim"></a>
  <a href="https://neovim.io/"><img src="https://img.shields.io/badge/Neovim-%E2%89%A50.11.2-a6e3a1?style=flat-square&amp;logo=neovim" alt="Neovim ≥ 0.11.2"></a>
  <img src="https://img.shields.io/badge/UI-%E4%B8%AD%E6%96%87_%2F_English-94e2d5?style=flat-square" alt="中文 / English">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache--2.0-cba6f7?style=flat-square" alt="Apache-2.0 License"></a>
</p>

沿用 [LazyVim](https://github.com/LazyVim/LazyVim) 的插件生态与快捷键，加入可切换汉化、Sidekick 多面板、居中浮动终端与 Catppuccin 透明主题。

![WindVim 启动页](docs/screenshots/dashboard-zh.png)

## 安装

> **前置要求**：Neovim ≥ 0.11.2（LuaJIT）、Git、`rsync`。完整依赖见[使用说明](docs/USAGE.md)。

在源码目录中安装：

```bash
cd windvim
./install.sh
~/.local/bin/windvim
```

默认使用独立配置 `~/.config/windvim`。首次启动自动下载插件；将 `~/.local/bin` 加入 PATH 后可直接运行 `windvim`。

## 快捷键

Leader 键是空格，其余操作沿用 [LazyVim 默认快捷键](https://www.lazyvim.org/keymaps)。

| 功能 | 快捷键 |
| --- | --- |
| 切换中文 / English | `<Space>uH` |
| 查找文件 / 搜索文本 | `<Space>ff` / `<Space>sg` |
| 文件浏览器 | `<Space>e` |
| 居中浮动终端 | `<Space>tp` |
| 切换 / 选择 AI CLI | `<Space>aa` / `<Space>as` |

## 文档

- [使用说明](docs/USAGE.md)：依赖、安装选项、AI 登录、定制、更新与卸载
- [界面预览](docs/GALLERY.md)：中文菜单、文件选择器、插件管理与英文界面
- [汉化插件](local-plugins/lazyvim-i18n.nvim/README.md)：翻译范围、语言切换与自定义词典
- [开发与分发](docs/DEVELOPMENT.md)：测试、截图复现与源码打包

## 许可

[Apache-2.0](LICENSE)。基于 [LazyVim](https://github.com/LazyVim/LazyVim) 和 [LazyVim Starter](https://github.com/LazyVim/starter)，感谢 [folke](https://github.com/folke) 及各插件作者；来源与修改说明见 [NOTICE](NOTICE)。
