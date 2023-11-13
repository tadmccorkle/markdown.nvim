# markdown.nvim <!-- omit in toc -->

![tests](https://github.com/tadmccorkle/markdown.nvim/actions/workflows/tests.yml/badge.svg?branch=master)

Tools for working with markdown files in Neovim.

- [Features](#features)
  - [Planned features](#planned-features)
- [Installation](#installation)
- [Getting help](#getting-help)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Inline surround](#inline-surround)
  - [Table of contents](#table-of-contents)
  - [List editing](#list-editing)
- [*nvim-treesitter* module](#nvim-treesitter-module)

## Features

- Inline-style
  - Keybindings over vim motions / visual selection
  - Toggle, delete, and change emphasis and code spans
  - Configurable keybindings and emphasis indicators
- Table of contents
  - Supports ATX and setext headings
  - Omit headings with an HTML tag
- Improved list editing
  - Insert new items
  - Auto-number ordered lists
  - Toggle task list items (GFM)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/) module support

### Planned features

- Table of contents
  - Configurable default list marker type
  - Specify list marker type
  - Configure omit heading tag
  - Omit section with HTML tag
- Links
  - Create links around highlighted text (visual mode)
  - Paste link/image from clipboard (visual mode)
  - Follow links
- Tables (GFM)
  - Formatting
  - Insert rows and columns

## Installation

**markdown.nvim** requires the [markdown and markdown_inline](https://github.com/MDeiml/tree-sitter-markdown) tree-sitter parsers. The easiest way to install these is with [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/).

Install **markdown.nvim** with your preferred plugin manager.

- [lazy.nvim](https://github.com/folke/lazy.nvim)

  ```lua
  {
    "tadmccorkle/markdown.nvim",
    event = "VeryLazy",
    opts = {
      -- configuration here or empty for defaults
    },
  }
  ```

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

  ```lua
  use({
    "tadmccorkle/markdown.nvim",
    config = function()
      require("markdown").setup({
        -- configuration here or empty for defaults
      })
    end,
  })
  ```

- [vim-plug](https://github.com/junegunn/vim-plug)

  ```vim
  Plug 'tadmccorkle/markdown.nvim'

  " after plug#end()
  " provide `setup()` configuration options or leave empty for defaults
  lua require('markdown').setup()
  ```

- [pckr.nvim](https://github.com/lewis6991/pckr.nvim)

  ```lua
  { "tadmccorkle/markdown.nvim",
    config = function()
      require("markdown").setup({
        -- configuration here or empty for defaults
      })
    end,
  };
  ```

## Getting help

**markdown.nvim** provides help docs that can be accessed by running `:help markdown.nvim`.

## Configuration

Detailed plugin configuration information can be found in the help doc (`:h markdown.configuration`).

A call to `require("markdown").setup()` is necessary for commands and keybindings to be registered in markdown buffers.

A table of configuration options can optionally be passed to the `setup()` function. Any fields in the table will overwrite the corresponding default. **markdown.nvim** uses the following defaults:

```lua
{
  inline_surround = {
    -- disable all inline keymaps by setting mappings field to "false"
    -- selectively disable keymaps by setting corresponding field to "false"
    mappings = {
      toggle = "gs", -- (string|boolean) toggle inline style
      toggle_line = "gss", -- (string|boolean) line-wise toggle inline style
      delete = "ds", -- (string|boolean) delete emphasis surrounding cursor
      change = "cs", -- (string|boolean) change emphasis surrounding cursor
    },
    -- for the emphasis, strong, strikethrough, and code fields:
    -- * key: used to specify an inline style in toggle, delete, and change operations
    -- * txt: text inserted when toggling or changing to the corresponding inline style
    emphasis = {
      key = "i",
      txt = "*",
    },
    strong = {
      key = "b",
      txt = "**",
    },
    strikethrough = {
      key = "s",
      txt = "~~",
    },
    code = {
      key = "c",
      txt = "`",
    },
  },
  on_attach = nil, -- (fun(bufnr: integer)) callback when plugin attaches to a buffer
}
```

`on_attach` is useful for creating additional buffer-only keymaps:

```lua
on_attach = function(bufnr)
  local map = vim.keymap.set
  local opts = { buffer = bufnr }
  map({ 'n', 'i' }, '<M-l><M-o>', '<Cmd>MDListItemBelow<CR>', opts)
  map({ 'n', 'i' }, '<M-L><M-O>', '<Cmd>MDListItemAbove<CR>', opts)
  map('n', '<M-c>', '<Cmd>MDTaskToggle<CR>', opts)
  map('x', '<M-c>', ':MDTaskToggle<CR>', opts)
end,
```

**markdown.nvim** can even be configured to support standard/typical inline style keybindings in visual mode like `<C-b>` for strong/bold and `<C-i>` for emphasis/italic:

```lua
on_attach = function(bufnr)
  local function toggle(key)
    return "<Esc>gv<Cmd>lua require'markdown.inline'"
      .. ".toggle_emphasis_visual'" .. key .. "'<CR>"
  end

  vim.keymap.set("x", "<C-b>", toggle("b"), { buffer = bufnr })
  vim.keymap.set("x", "<C-i>", toggle("i"), { buffer = bufnr })
end,
```

## Usage

Detailed usage instructions can be found in the help doc (`:h markdown.usage`).

**markdown.nvim** is broken up into different feature categories:

- [Inline Surround](#inline-surround)
- [Table of Contents](#table-of-contents)
- [List Editing](#list-editing)

### Inline surround

**markdown.nvim** provides inline keymaps to toggle, delete, and change emphasis and code spans, referred to in this section as "styles". The supported styles and the default keys used to refer to them are:

| Style                                   | Key |
|:----------------------------------------|:---:|
| emphasis (typically rendered in italic) | "i" |
| strong (typically rendered in bold)     | "b" |
| strikethrough                           | "s" |
| code span                               | "c" |

- #### Toggle <!-- omit in toc -->

  Inline styles can be toggled over vim motions in normal and visual mode. Toggled styles are only applied to appropriate markdown elements (i.e., not blank lines, list markers, etc.). For example, a motion that includes a list marker and multiple blocks will only apply the style to inline content:

  ```txt
          toggle strong over five lines
  -----------------------------------------------
  paragraph block             **paragraph block**
  - list item                 - **list item**
                      ---->
  another paragraph           **another pargraph
  over two lines              over two lines**
  ```

  In normal mode this is done with **gs{motion}{style}**, where **{style}** is the key corresponding to the style to toggle. Like other vim motions, a **[count]** can be specified before and after the **gs**. Styles can also be toggled over the current line using **gss{style}**. A **[count]** can be specified to toggle over multiple lines.

  | Before             | Command | After           |
  |:-------------------|:-------:|:----------------|
  | `^some text`       |  gs2es  | `~~some text~~` |
  | `some t^ext`       |  gsiwb  | `some **text**` |
  | `some *t^ext*`     |  gsiwi  | `some text`     |
  | `***some^ text***` |  gssb   | `*some text*`   |

  `^` denotes cursor position

  Styles can be toggled in visual mode based on a visual selection using
  **gs{style}**.

  | Before              | Command | After           |
  |:--------------------|:-------:|:----------------|
  | `^some text$`       |   gss   | `~~some text~~` |
  | `some ^text$`       |   gsb   | `some **text**` |
  | `some *^text$*`     |   gsi   | `some text`     |
  | `***^some text$***` |   gsb   | `*some text*`   |

  `^` and `$` denote selection start and end, respectively

  Styles can also be toggled in visual block mode.

  ```txt
  Before          | Command | After
  ----------------|---------|----------------
  - list ^item$ 1 |         | - list *item* 1
  - li2           |         | - li2
                  |   gsi   |
  - list ^item$ 3 |         | - list *item* 3
  - list ^item$ 4 |         | - list *item* 4

  `^` and `$` denote block selection start and end on each line, respectively
  ```

- #### Delete <!-- omit in toc -->

  Inline styles around the cursor can be deleted in normal mode using **ds{style}**, where **{style}** is the key corresponding to the style to delete. Only the style directly surrounding the cursor will be deleted.

  | Before               | Command | After           |
  |:---------------------|:-------:|:----------------|
  | `**some^ *text***`   |   dsb   | `some *text*`   |
  | `**some *t^ext***`   |   dsb   | `some *text*`   |
  | `**some **t^ext****` |   dsb   | `**some text**` |

  `^` denotes cursor position

- #### Change <!-- omit in toc -->

  Inline styles around the cursor can be changed in normal mode using **cs{from}{to}**, where **{from}** and **{to}** are the keys corresponding to the current style (**{from}**) and the new style (**{to}**). Only the matching **{from}** style directly surrounding the cursor will be changed.

  | Before               | Command | After               |
  |:---------------------|:-------:|:--------------------|
  | `**some^ *text***`   |  csbi   | `*some *text**`     |
  | `**some *t^ext***`   |  csbi   | `*some *text**`     |
  | `**some **t^ext****` |  csbs   | `**some ~~text~~**` |

  `^` denotes cursor position

### Table of contents

The `:MDInsertToc` command adds a table of contents (TOC) for the current markdown buffer by inserting (normal mode) or replacing selected lines (visual mode). The TOC is based on ATX and setext headings.

#### Omit headings <!-- omit in toc -->

Headings can be omitted from the TOC by flagging them with `<!-- omit in toc -->`. The flag can either be placed directly above (i.e., on the line immediately preceding) or within the heading content. For example, the following headings would be omitted:

```md
# heading 1 <!-- omit in toc -->

<!-- omit in toc -->
## heading 2
```

### List editing

Most list editing commands are intended to be invoked by custom keymaps (see notes on the `on_attach` field under [configuration](#configuration)).

- #### Inserting items <!-- omit in toc -->

  Use the `:MDListItemBelow` and `:MDListItemAbove` commands to insert a new list item below and above the current cursor position, respectively. Both commands maintain the same indentation and list marker as the item under the cursor. The commands do nothing if the cursor is not within an existing list.

  When inserting an item in an ordered list, numbering is reset automatically for that list. To reset numbering for all ordered lists in a buffer see [reset numbering](#reset-numbering).

- #### Reset numbering <!-- omit in toc -->

  The `:MDResetListNumbering` command resets the numbering of all ordered lists in the current buffer.

- #### Toggle tasks <!-- omit in toc -->

  The `:MDTaskToggle` command toggles the task(s) on the current cursor line (normal mode) or under the current visual selection (visual mode).

## *nvim-treesitter* module

<details>
<summary><strong>markdown.nvim</strong> can also be configured as an <a href="https://github.com/nvim-treesitter/nvim-treesitter/">nvim-treesitter</a> module.</summary>

### Module installation <!-- omit in toc -->

The following code snippets show how to install **markdown.nvim** as an **nvim-treesitter** module. Refer to [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/) for the appropriate way to install and manage parsers.

- [lazy.nvim](https://github.com/folke/lazy.nvim)

  ```lua
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "tadmccorkle/markdown.nvim" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "markdown", "markdown_inline", --[[ other parsers you need ]] },
        markdown = {
          enable = true,
          -- configuration here or nothing for defaults
        },
      })
    end,
  }
  ```

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

  ```lua
  use({
    "nvim-treesitter/nvim-treesitter",
    requires = { { "tadmccorkle/markdown.nvim" } },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "markdown", "markdown_inline", --[[ other parsers you need ]] },
        markdown = {
          enable = true,
          -- configuration here or nothing for defaults
        },
      })
    end,
  })
  ```

- [vim-plug](https://github.com/junegunn/vim-plug)

  ```vim
  Plug 'nvim-treesitter/nvim-treesitter'
  Plug 'tadmccorkle/markdown.nvim'

  " after plug#end()
  lua << EOF
  require("nvim-treesitter.configs").setup({
    ensure_installed = { "markdown", "markdown_inline", --[[ other parsers you need ]] },
    markdown = {
      enable = true,
      -- configuration here or nothing for defaults
    },
  })
  EOF
  ```

- [pckr.nvim](https://github.com/lewis6991/pckr.nvim)

  ```lua
  { "nvim-treesitter/nvim-treesitter",
    requires = { "tadmccorkle/markdown.nvim" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "markdown", "markdown_inline", --[[ other parsers you need ]] },
        markdown = {
          enable = true,
          -- configuration here or nothing for defaults
        },
      })
    end,
  };
  ```

### Module configuration <!-- omit in toc -->

When **markdown.nvim** is configured as an **nvim-treesitter** module, configuration options are passed to the `require("nvim-treesitter.configs").setup()` function. All configuration options are the same as described in the [configuration](#configuration) section.

```lua
local configs = require("nvim-treesitter.configs")

configs.setup({
  ensure_installed = { "markdown", "markdown_inline", --[[ other parsers you need ]] },
  markdown = {
    enable = true, -- must be specified to enable markdown.nvim as a module
    -- configuration here or nothing for defaults
  },
})
```

</details>
