# codereview.nvim

Local code review for Neovim.

`codereview.nvim` opens a git changeset in Neovim, lets you review changed files with normal editor navigation, attach line comments, and dump the comments as structured Markdown for an AI agent or review note.

The main workflow is:

1. Start a review from a git diff, ref picker, or GitHub PR URL.
2. Move through changed files with keymaps or Telescope.
3. Select changed lines on the new side and add comments.
4. Dump all comments to the clipboard as Markdown.

## Status

This plugin is early and intentionally pragmatic. It is usable for local AI-assisted review workflows, but the UI and persistence model are still evolving.

## Features

- Side-by-side diff view for modified files.
- Single-pane view for newly added files.
- Syntax highlighting through Neovim filetypes and Tree-sitter when available.
- Visual-line comments on the new side of a diff.
- Comment signs, line-number highlighting, and expandable virtual-line hints.
- Soft-delete comment workflow with undo.
- Persistent sessions and comments in a local SQLite database.
- Resume active review sessions.
- File picker through Telescope, with `vim.ui.select` fallback.
- Next/previous file navigation.
- Reviewed-file tracking.
- Markdown dump to the system clipboard.
- GitHub PR URL support through the `gh` CLI.
- Reuses an existing active review when the source, repo, base, and target match.

## Requirements

- Neovim 0.10 or newer.
- `git`.
- `sqlite3` CLI for persistence.
- `gh` CLI for GitHub PR reviews.
- A clipboard provider for `+` register support.

Recommended plugins:

- `nvim-telescope/telescope.nvim`
- `nvim-lua/plenary.nvim`
- `nvim-tree/nvim-web-devicons`

The plugin has fallback paths for some optional UI integrations, but Telescope gives the best file-picking experience.

## Installation

### lazy.nvim

```lua
{
  "uhvesta/nvim-reviewtool",
  name = "codereview.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "CodeReview",
  keys = {
    { "<leader>crN", desc = "CodeReview new session" },
    { "<leader>crS", desc = "CodeReview resume session" },
    { "<leader>crc", mode = "v", desc = "CodeReview comment" },
    { "<leader>crt", desc = "CodeReview toggle comments" },
    { "<leader>cra", desc = "CodeReview anchor misplaced comment" },
    { "<leader>crx", desc = "CodeReview delete comment" },
    { "<leader>crC", desc = "CodeReview comments" },
    { "<leader>crd", desc = "CodeReview dump" },
    { "<leader>crn", desc = "CodeReview next file" },
    { "<leader>crp", desc = "CodeReview previous file" },
    { "<leader>crs", desc = "CodeReview files" },
    { "<leader>crr", desc = "CodeReview toggle reviewed" },
    { "<leader>crm", desc = "CodeReview summary" },
    { "<leader>crq", desc = "CodeReview close" },
    { "<leader>cru", desc = "CodeReview undo" },
    { "<leader>crR", desc = "CodeReview redo" },
  },
  config = function()
    require("codereview").setup({})
  end,
}
```

For local development:

```lua
{
  dir = vim.fn.expand("~/oss/codereview/nvim-reviewtool"),
  name = "codereview.nvim",
  config = function()
    require("codereview").setup({})
  end,
}
```

## Usage

Start a new review:

```vim
:CodeReview new
```

With no source, this opens a ref picker. You can also pass a git diff spec:

```vim
:CodeReview new HEAD
:CodeReview new main...HEAD
:CodeReview new HEAD~3..HEAD
```

Review a GitHub PR:

```vim
:CodeReview new https://github.com/OWNER/REPO/pull/123
```

Resume a session:

```vim
:CodeReview resume
```

Dump comments to the clipboard:

```vim
:CodeReview dump
```

Dump without snippets:

```vim
:CodeReview dump --no-snippets
```

## Comment Workflow

Comments are added only on the new side of the review.

1. Move to the new/right code pane.
2. Visual-select the lines to comment on with `V`.
3. Press `<leader>crc`.
4. Type the comment in the floating window.
5. Save with `:w`, `<C-s>`, or normal-mode `<Enter>`.

Cancel the comment window with `q` or `<C-c>`.

Comment display:

- Expanded comments show wrapped virtual lines under the commented code.
- Collapsed comments keep the sign-column marker and line highlight.
- `<leader>crt` toggles all comments in the current file.
- `<leader>crx` opens a picker to soft-delete a comment in the current file.
- Deleted comments can be restored with `<leader>cru`.

## Default Keymaps

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>crN` | normal | Start a new review session |
| `<leader>crS` | normal | Resume a review session |
| `<leader>crc` | visual | Add a comment |
| `<leader>crt` | normal | Toggle all comments in the current file |
| `<leader>cra` | normal | Anchor a misplaced legacy comment at the cursor |
| `<leader>crx` | normal | Soft-delete a comment |
| `<leader>crC` | normal | List comments |
| `<leader>crd` | normal | Dump comments to clipboard |
| `<leader>crn` | normal | Next changed file |
| `<leader>crp` | normal | Previous changed file |
| `<leader>crs` | normal | Open changed-file picker |
| `<leader>crr` | normal | Toggle current file reviewed |
| `<leader>crm` | normal | Show summary |
| `<leader>crq` | normal | Close review session |
| `<leader>cru` | normal | Undo comment action |
| `<leader>crR` | normal | Redo comment action |

## Commands

```vim
:CodeReview new [source]
:CodeReview resume [session_id]
:CodeReview files
:CodeReview next
:CodeReview prev
:CodeReview comment
:CodeReview comments
:CodeReview anchor
:CodeReview delete
:CodeReview reviewed
:CodeReview dump [--no-snippets]
:CodeReview summary
:CodeReview close
:CodeReview undo
:CodeReview redo
```

## Configuration

```lua
require("codereview").setup({
  enable_lsp = true,
  include_snippets = true,
  checkout_dir = vim.fn.expand("~/nvim-gh-review"),
  keymaps = {
    new = "<leader>crN",
    resume = "<leader>crS",
    comment = "<leader>crc",
    toggle_comment = "<leader>crt",
    anchor_comment = "<leader>cra",
    delete_comment = "<leader>crx",
    comments = "<leader>crC",
    dump = "<leader>crd",
    next = "<leader>crn",
    prev = "<leader>crp",
    search = "<leader>crs",
    reviewed = "<leader>crr",
    summary = "<leader>crm",
    close = "<leader>crq",
    undo = "<leader>cru",
    redo = "<leader>crR",
  },
})
```

## Markdown Output

`:CodeReview dump` copies Markdown like this to the system clipboard:

````markdown
# Code Review: main...HEAD @ 2026-06-29 12:00

## `src/example.ts`

### Line 42

```typescript
const value = compute()
```

Please handle the error case here.
````

## Tests

Run the headless test suite with:

```sh
make test
```

The test runner uses temporary XDG data/state/cache directories, so it does not touch your normal Neovim state or CodeReview database.

## Publishing

To publish this plugin:

1. Create a GitHub repository named `nvim-reviewtool`.
2. Point this local repo at it:

   ```sh
   git remote set-url origin git@github.com:uhvesta/nvim-reviewtool.git
   ```

3. Commit and push:

   ```sh
   git add README.md LICENSE Makefile tests lua plugin
   git commit -m "Prepare codereview.nvim for publishing"
   git push -u origin main
   ```

4. Optional but recommended: create a GitHub release/tag once the first public version is stable.

After pushing, users can install with:

```lua
{ "uhvesta/nvim-reviewtool", name = "codereview.nvim" }
```

## License

MIT
