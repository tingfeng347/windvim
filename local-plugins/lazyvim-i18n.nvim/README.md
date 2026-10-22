# lazyvim-i18n.nvim

独立的离线汉化层，默认简体中文，可在运行时切换英语并记住选择。实现与词典都在这个目录内，不修改已安装插件的源码，也不改变系统语言。

## 使用

- `<leader>uH`：切换中文/English；本配置的 leader 是空格。
- `:LazyVimLanguage zh_CN`：中文。
- `:LazyVimLanguage en`：英文。
- `:LazyVimLanguage toggle`：切换。
- `:LazyVimLanguage`：查看当前语言。

重启独立配置 `lazyvim` 后生效。已打开的 Lazy、which-key、Snacks 选择器和启动页在切换时刷新。

语言保存在 `stdpath("state") .. "/lazyvim-i18n/locale"`，与其他 Neovim 配置隔离。加载顺序为 `LAZYVIM_LANGUAGE` 环境变量 > 已保存的选择 > `opts.locale`。例如：

```sh
NVIM_APPNAME=lazyvim LAZYVIM_LANGUAGE=en nvim
```

环境变量只决定本次启动时的语言；本次使用命令切换仍会保存新选择。设置 `persist = false` 可关闭读写保存状态。删掉上述状态文件即可恢复配置默认值。

## 覆盖范围

| 界面 | 已适配的文字 |
| --- | --- |
| which-key | 分组、已收录的快捷键说明、关闭/返回/滚动底栏 |
| lazy.nvim | 顶部按钮、列表分区、数量、更新状态、帮助页 |
| Snacks Picker / Explorer | 文件、搜索、缓冲区等常用选择器标题，结果标题和预览占位标题 |
| Snacks Dashboard | 常用菜单项及当前 WindVim 启动统计文案；原先写死的中文也能切回英文 |

插件名、快捷键、命令名、路径、文件内容、Git 提交内容及预览内容不翻译。Mason、Noice 等其他插件自身的弹窗，以及未收录的动态文字，仍显示原文。这是按界面适配的语言层，不是整个 Neovim 的全文替换器。

## 配置与插拔

当前入口是 `lua/plugins/i18n.lua`。将其中 `enabled = true` 改为 `false`，或删除该入口文件，然后重启，即可卸载本层；目录内代码可以保留。运行中调用 `require("lazyvim_i18n").teardown()` 可撤销本层安装的函数包装和语言命令。已有启动页本来就是中文，卸载后恢复它原有的文案。

整个目录也可以单独移到其他位置，使用本地插件声明：

```lua
return {
  {
    dir = "/path/to/lazyvim-i18n.nvim",
    lazy = false,
    priority = 10000,
    opts = {
      locale = "zh_CN",
      persist = true,
      keymap = "<leader>uH", -- false 可禁用快捷键
      -- state_file = "/custom/path/locale",
      translations = {
        keymaps = { ["Find Files"] = "查找文件" },
        picker = { ["Files"] = "文件" },
      },
    },
    config = function(_, opts)
      require("lazyvim_i18n").setup(opts)
    end,
  },
}
```

`translations` 按 `keymaps / which_key / lazy / picker / dashboard` 分域覆盖词典。相同文本在不同界面可分别翻译。调用 `get_locale()`、`set_locale("en")`、`toggle()` 可集成自己的开关；切换会发送 `User LazyVimLanguageChanged` 事件，`event.data.locale` 为新语言。

## 实现与维护

- `dictionary.lua`：界面词典、有限的数量/目录后缀模板、未命中回退。
- `adapters.lua`：限定在各插件的 UI 渲染入口，切换时从原文重新渲染；中文宽度按显示单元计算，高亮仍按字节定位。
- `hooks.lua`：仅观察列明的 Lua 模块加载并安装适配，不提前加载弹窗；卸载时恢复原方法及继承关系。
- `init.lua`：语言选择、保存、命令、快捷键和界面刷新。

上游缺少统一 i18n API，所以 lazy.nvim、which-key 底栏和 Snacks 使用了局部函数包装，存在上游接口变动后的维护成本。适配不修改模块源文件；新增上游文字默认显示原文。建议更新这些插件后运行下面的真实 UI 集成测试。

```sh
cd ~/.config/lazyvim
uv run --with pynvim --with pillow python local-plugins/lazyvim-i18n.nvim/tests/run.py
```

测试使用临时语言状态文件，附加真实 Neovim UI，覆盖中英切换、保存恢复、原文保护、窄屏标题、卸载恢复和四类面板。截图保存在 Git 忽略的 `.tests/i18n/`。测试截图字体路径使用本机 JetBrains Maple Mono；换机器时可调整 `tests/run.py` 的字体路径。

## 调研依据

- [lazyvim.chinese](https://github.com/xuxiaowei-com-cn/lazyvim.chinese)：可开关的菜单分组汉化，覆盖范围小于本次需求。
- [which-key 配置](https://github.com/folke/which-key.nvim#%EF%B8%8F-configuration)：提供描述格式化，图标依据原文匹配。
- [lazy.nvim](https://github.com/folke/lazy.nvim)：当前界面没有统一语言配置，本次核对并适配实际安装的渲染器。
- [Snacks Picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md)：按选择器标题模板进行局部翻译。

以上实现以本机 `lazy-lock.json` 指向的已安装版本为验证基线，而非假定上游最新版本接口完全相同。
