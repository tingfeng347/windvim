return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- Match the separate nvim configuration: render in normal, command, and
      -- terminal modes, and reveal Markdown syntax while it is being edited.
      max_file_size = 2.0,
      debounce = 100,
      render_modes = { "n", "c", "t" },
      anti_conceal = { enabled = true },
      log_level = "error",
      -- Keep heading markers and labels with level-specific text colours,
      -- while title-strip backgrounds remain transparent.
      heading = {
        enabled = true,
        atx = true,
        setext = true,
        -- nvim leaves these signs enabled; they are the left-gutter labels
        -- beside headings in the reference screenshot.
        sign = true,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        position = "inline",
        width = "block",
        backgrounds = { "Normal" },
        foregrounds = {
          "RenderMarkdownH1",
          "RenderMarkdownH2",
          "RenderMarkdownH3",
          "RenderMarkdownH4",
          "RenderMarkdownH5",
          "RenderMarkdownH6",
        },
        border = false,
      },
      -- Render code in a full-width block without adding an opaque surface.
      code = {
        sign = true,
        style = "full",
        width = "full",
        right_pad = 0,
      },
      checkbox = {
        enabled = true,
      },
    },
  },
}
