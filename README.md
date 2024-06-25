# markdown.nvim <!-- toc omit heading -->

Configurable tools for working with markdown files in Neovim.

[![ci](https://github.com/tadmccorkle/markdown.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/tadmccorkle/markdown.nvim/actions/workflows/ci.yml)
[![tests (nightly)](https://github.com/tadmccorkle/markdown.nvim/actions/workflows/tests-nightly.yml/badge.svg)](https://github.com/tadmccorkle/markdown.nvim/actions/workflows/tests-nightly.yml)

![markdown-nvim-demo](https://github.com/tadmccorkle/markdown.nvim/assets/41654369/b3b7c85f-2a37-4b79-ba5e-e75b39d45098 "markdown.nvim demo")

## Contents <!-- toc omit heading -->

- [Features](#features)
  - [Planned features](#planned-features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting help](#getting-help)
- [Configuration](#configuration)
  - [`<Plug>` mappings](#plug-mappings)
- [Usage](#usage)
  - [Inline surround](#inline-surround)
  - [Table of contents](#table-of-contents)
  - [Lists](#lists)
  - [Links](#links)
  - [Navigation](#navigation)
- [*nvim-treesitter* module](#nvim-treesitter-module)

## Features

- Inline-style
  - Keybindings over vim motions / visual selection
  - Toggle, delete, and change emphasis and code spans
- Table of contents
  - Insert as list with configurable markers
  - Show in current window's location list
  - Omit entire sections and individual headings with an HTML tag
- Lists
  - Insert new items
  - Auto-number ordered lists
  - Toggle task list items (GFM)
  - Toggle between list types
- Links
  - Add links over vim motions / visual selection
  - Follow links under the cursor
  - Paste URLs from clipboard over visual selection as links
- Navigation
  - Jump to the current, parent, next, and previous heading
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/) module support

### Planned features

- Tables (GFM)
  - Formatting
  - Insert rows and columns

## Requirements

- Neovim >=0.9.0
- [markdown and markdown_inline](https://github.com/MDeiml/tree-sitter-markdown) tree-sitter parsers. The easiest way to install these is with [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/).

## Installation

Install **markdown.nvim** with your preferred plugin manager.

- [lazy.nvim](https://github.com/folke/lazy.nvim)

  ```lua
  {
    "tadmccorkle/markdown.nvim",
    ft = "markdown", -- or 'event = "VeryLazy"'
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
  -- Disable all keymaps by setting mappings field to 'false'.
  -- Selectively disable keymaps by setting corresponding field to 'false'.
  mappings = {
    inline_surround_toggle = "gs", -- (string|boolean) toggle inline style
    inline_surround_toggle_line = "gss", -- (string|boolean) line-wise toggle inline style
    inline_surround_delete = "ds", -- (string|boolean) delete emphasis surrounding cursor
    inline_surround_change = "cs", -- (string|boolean) change emphasis surrounding cursor
    link_add = "gl", -- (string|boolean) add link
    link_follow = "gx", -- (string|boolean) follow link
    go_curr_heading = "]c", -- (string|boolean) set cursor to current section heading
    go_parent_heading = "]p", -- (string|boolean) set cursor to parent section heading
    go_next_heading = "]]", -- (string|boolean) set cursor to next section heading
    go_prev_heading = "[[", -- (string|boolean) set cursor to previous section heading
  },
  inline_surround = {
    -- For the emphasis, strong, strikethrough, and code fields:
    -- * 'key': used to specify an inline style in toggle, delete, and change operations
    -- * 'txt': text inserted when toggling or changing to the corresponding inline style
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
  link = {
    paste = {
      enable = true, -- whether to convert URLs to links on paste
    },
  },
  toc = {
    -- Comment text to flag headings/sections for omission in table of contents.
    omit_heading = "toc omit heading",
    omit_section = "toc omit section",
    -- Cycling list markers to use in table of contents.
    -- Use '.' and ')' for ordered lists.
    markers = { "-" },
  },
  -- Hook functions allow for overriding or extending default behavior.
  -- Called with a table of options and a fallback function with default behavior.
  -- Signature: fun(opts: table, fallback: fun())
  hooks = {
    -- Called when following links. Provided the following options:
    -- * 'dest' (string): the link destination
    -- * 'use_default_app' (boolean|nil): whether to open the destination with default application
    --   (refer to documentation on <Plug> mappings for explanation of when this option is used)
    follow_link = nil,
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

### `<Plug>` mappings

**markdown.nvim** sets up `<Plug>` mappings regardless of configuration. Most are used by the configuration mappings described above:

| `<Plug>` Mapping                           | Configuration Mapping         |
| ------------------------------------------ | ----------------------------- |
| `<Plug>(markdown_toggle_emphasis)`         | `inline_surround_toggle`      |
| `<Plug>(markdown_toggle_emphasis_line)`    | `inline_surround_toggle_line` |
| `<Plug>(markdown_toggle_emphasis_visual)`  | `inline_surround_toggle`      |
| `<Plug>(markdown_delete_emphasis)`         | `inline_surround_delete`      |
| `<Plug>(markdown_change_emphasis)`         | `inline_surround_change`      |
| `<Plug>(markdown_add_link)`                | `link_add`                    |
| `<Plug>(markdown_add_link_visual)`         | `link_add`                    |
| `<Plug>(markdown_follow_link)`             | `link_follow`                 |
| `<Plug>(markdown_go_current_heading)`      | `go_curr_heading`             |
| `<Plug>(markdown_go_parent_heading)`       | `go_parent_heading`           |
| `<Plug>(markdown_go_next_heading)`         | `go_next_heading`             |
| `<Plug>(markdown_go_prev_heading)`         | `go_prev_heading`             |

The following `<Plug>` mappings are not used by **markdown.nvim**'s configuration:

| `<Plug>` Mapping                           | Description                                                                                                                                                                                                                                |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `<Plug>(markdown_follow_link_default_app)` | Like `<Plug>(markdown_follow_link)` but opens links to non-markdown files in the default application for the link destination. The hook `follow_link` is called before following the link with the option 'use_default_app' set to 'true'. |

## Usage

Detailed usage instructions can be found in the help doc (`:h markdown.usage`).

**markdown.nvim** is broken up into different feature categories:

- [Inline Surround](#inline-surround)
- [Table of Contents](#table-of-contents)
- [Lists](#lists)
- [Links](#links)
- [Navigation](#navigation)

### Inline surround

**markdown.nvim** provides keymaps to toggle, delete, and change emphasis and code spans, referred to in this section as "styles". The supported styles and the default keys used to refer to them are:

| Style                                   | Key |
|:----------------------------------------|:---:|
| emphasis (typically rendered in italic) | "i" |
| strong (typically rendered in bold)     | "b" |
| strikethrough                           | "s" |
| code span                               | "c" |

- #### Toggle

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

- #### Delete

  Inline styles around the cursor can be deleted in normal mode using **ds{style}**, where **{style}** is the key corresponding to the style to delete. Only the style directly surrounding the cursor will be deleted.

  | Before               | Command | After           |
  |:---------------------|:-------:|:----------------|
  | `**some^ *text***`   |   dsb   | `some *text*`   |
  | `**some *t^ext***`   |   dsb   | `some *text*`   |
  | `**some **t^ext****` |   dsb   | `**some text**` |

  `^` denotes cursor position

- #### Change

  Inline styles around the cursor can be changed in normal mode using **cs{from}{to}**, where **{from}** and **{to}** are the keys corresponding to the current style (**{from}**) and the new style (**{to}**). Only the matching **{from}** style directly surrounding the cursor will be changed.

  | Before               | Command | After               |
  |:---------------------|:-------:|:--------------------|
  | `**some^ *text***`   |  csbi   | `*some *text**`     |
  | `**some *t^ext***`   |  csbi   | `*some *text**`     |
  | `**some **t^ext****` |  csbs   | `**some ~~text~~**` |

  `^` denotes cursor position

### Table of contents

A table of contents (TOC) is created from the top-level ATX and setext headings of markdown buffers.

The `:MDInsertToc [max_level] [markers]` command adds a TOC by inserting (normal mode) or replacing selected lines (visual mode). Optional arguments can be provided to set the max heading level to include and the list markers to alternate through for each heading level.

The `:MDToc [max_level]` and `:MDTocAll [max_level]` commands show a TOC for the current buffer in the current window's location list. `:MDToc` omits flagged headings and `MDTocAll` includes all headings. An optional argument can be provided to set the max heading level to include.

#### Omit sections and headings <!-- toc omit heading -->

Headings and entire sections can be omitted from the TOC by flagging them with `<!-- toc omit heading -->` and `<!-- toc omit section -->`, respectively. The flag can either be placed directly above (i.e., on the line immediately preceding) or within the heading content. For example, the following headings would be omitted:

```md
# heading 1 <!-- toc omit heading -->

<!-- toc omit heading -->
## heading 2

<!-- toc omit section -->
# section heading omitted
## subsection heading also omitted
```

### Lists

Most list editing commands are intended to be invoked by custom keymaps (see notes on the `on_attach` field under [configuration](#configuration)).

- #### Inserting items

  Use the `:MDListItemBelow` and `:MDListItemAbove` commands to insert a new list item below and above the current cursor position, respectively. Both commands maintain the same indentation and list marker as the item under the cursor. The commands do nothing if the cursor is not within an existing list.

  When inserting an item in an ordered list, numbering is reset automatically for that list.

- #### Reset numbering

  The `:MDResetListNumbering` command resets the numbering of all ordered lists in the current buffer (normal mode) or under the current visual selection (visual mode).

- #### Toggle tasks

  The `:MDTaskToggle` command toggles the task(s) on the current cursor line (normal mode) or under the current visual selection (visual mode).

- #### Toggle list types

  The `:MDToggleListType [list_type]` command allows you to switch between ordered, unordered, and task list types at the current cursor position or within a selected range or for a list under cursor. The command accepts a single argument specifying the desired list type.

  Examples:

  - `:MDToggleListType ordered`: Toggle the current or selected list(s) to an ordered list.
  - `:MDToggleListType unordered`: Toggle the current or selected list(s) to an unordered list.
  - `:MDToggleListType task`: Toggle the current or selected list(s) to a task list.

### Links

- #### Add

  Links can be added over vim motions in normal and visual mode. Links are only added when the motion is within one inline block (i.e., not over list markers, blank lines, etc.). In normal mode this is done with **gl{motion}** and over a visual selection with **gl**.

- #### Follow

  Follow links under the cursor in normal mode with **gx**. Supported in-editor navigation:

  - `#destination`: headings in the current buffer
  - `./destination`: files and directories relative to the current buffer
  - `/destination`: files and directories relative to the working directory
  - Other absolute path destinations are opened if they exist

  URL destinations are opened in the browser.

- #### Paste URLs

  URLs can be pasted over a visual selection (not a visual block selection) from the system clipboard as markdown links. The visual selection must be contained by one inline block (i.e., conversion to a link will not occur if the visual selection includes blank lines, list markers, etc.).

### Navigation

Markdown buffers can be navigated with the following keymaps:

- `]c`: go to the current section heading
- `]p`: go to the parent section heading
- `]]`: go to the next section heading
- `[[`: go to the previous section heading

## *nvim-treesitter* module

<details>
<summary><strong>markdown.nvim</strong> can also be configured as an <a href="https://github.com/nvim-treesitter/nvim-treesitter/">nvim-treesitter</a> module.</summary>

### Module installation <!-- toc omit heading -->

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

### Module configuration <!-- toc omit heading -->

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
