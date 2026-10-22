# 开发与分发

[返回首页](../README.md)

## 本地开发

在项目根目录执行以下命令。配置修改先在独立的测试配置中验证，再按需部署；项目源码和安装目录由安装器复制隔离。

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

## 源码分发

项目目前仅在本地维护；公开发布后，用户可通过 GitHub 克隆或下载源码包安装。提交改动后，也可以生成包含文档和截图的分享包：

```bash
mkdir -p .dist
git archive --format=tar.gz --prefix=windvim/ HEAD -o .dist/windvim.tar.gz
```

接收者解压后按[使用说明](USAGE.md)安装，无需 dotfiles 或原仓库的 Git 历史。

## GitHub 发布

计划仓库：`https://github.com/tingfeng347/windvim`，默认分支 `main`。在 GitHub 创建空仓库后，维护者可在本项目中执行：

```bash
git remote add origin https://github.com/tingfeng347/windvim.git
git push -u origin main
```

README 已按此地址准备克隆安装命令；改用其他账号或仓库名时，一并修改文档中的下载地址。本项目不在本地自动创建仓库或推送。

## 来源与目录

WindVim 从 [dotfiles](https://github.com/tingfeng347/dotfiles) 的 LazyVim 模块复制，保留相关 Git 历史。原 dotfiles 模块和本机已安装配置独立保留；修改 WindVim 项目不会自动同步它们。

- `lua/config/`：通用 Neovim 设置。
- `lua/plugins/`：主题、启动页、AI 面板和快捷键定制。
- `local-plugins/lazyvim-i18n.nvim/`：可插拔的常用界面汉化层。
- `docs/assets/windvim.svg`：项目图标，W 字形与风线组成。
- `spec/`：需求、方案和验收记录。

`lua/windvim/logo.lua` 使用小型深度缓冲绘制管状 W、风环和粒子，每 120ms 更新一次字符覆盖层；菜单缓冲区和光标保持稳定。动画在后台、窄窗口或低高度终端暂停，`WINDVIM_ANIMATION=0` 可保持静态。

动态预览由真实 Neovim UI 网格录制。在截图命令前添加 `WINDVIM_CAPTURE_ANIMATION=1`，同时输出 `dashboard-animation.gif`。
