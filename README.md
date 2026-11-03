# dotfiles

Stow-managed dotfiles: tmux, yazi, Neovim, Ghostty, lazygit, delta and the Claude Code status line, themed tokyonight night across the board.

## Install

```bash
git clone https://github.com/defuserVMAgent/dotfiles.git ~/dotfiles
cd ~/dotfiles
mkdir -p ~/.config ~/.claude ~/.local/bin   # must exist first, see below
stow */
```

Needs [GNU Stow](https://www.gnu.org/software/stow/) (`brew install stow`).

Why the `mkdir`: if a target directory doesn't exist, Stow "folds" it into a single symlink to the repo. A folded `~/.claude` or `~/.local` would make Claude Code (credentials, session history) and other tools write their state straight into this public repo. Pre-created, they get per-file symlinks instead.

If a target file already exists as a regular file (e.g. an old `~/.claude/statusline.sh`), Stow refuses with a conflict; move it out of the way and re-run.

lazygit/delta extras:

```bash
brew install lazygit git-delta bat
bat cache --build   # compiles bat/.config/bat/themes — delta reads bat's cache
# macOS lazygit ignores ~/.config; point its Application Support config at the stowed one
ln -sf ~/.config/lazygit/config.yml ~/Library/Application\ Support/lazygit/config.yml
```

Claude Code status line + tmux hooks: `brew install jq`, then merge `settings.tmux.json` into `~/.claude/settings.json` (command in [tmux: Claude Code usage + tab colors](#tmux-claude-code-usage--tab-colors)).

## Packages

- `ghostty` — Ghostty terminal (`~/.config/ghostty/config`; Ghostty reads the XDG path on macOS)
- `nvim` — Neovim (LazyVim)
- `tmux` — tmux (vim-tmux-navigator pane switching, vi copy mode, minimal status bar at the top with Claude Code plan usage on the right; `prefix ]` opens the current pane's scrollback in nvim via `~/.local/bin/tmux-capture-to-nvim`)
- `yazi` — Yazi file manager
- `lazygit` — lazygit (`~/.config/lazygit/config.yml`, symlinked from Application Support); diffs rendered by delta, side-by-side when the pane is >160 cols, `|` cycles to git's plain diff
- `git` — `~/.config/git/config`: delta as git's pager. Git reads it *alongside* `~/.gitconfig`, which stays unstowed for identity/credentials
- `bat` — bat config + the tokyonight `.tmTheme` delta uses for syntax highlighting
- `claude` — Claude Code status line (`~/.claude/statusline.sh`) and the tmux tab-color hooks (`~/.claude/settings.tmux.json`, merged into `settings.json` by hand — see below)

## Theme

tokyonight night everywhere. Assets for **both** tokyonight and Catppuccin Mocha stay vendored in the repo — only the selection line differs per app, so switching is a handful of one-line edits:

| App     | Theme selected in                                                              |
| ------- | ------------------------------------------------------------------------------ |
| nvim    | `colorscheme` opt in `nvim/.config/nvim/lua/plugins/colorscheme.lua`            |
| ghostty | inline `background`/`foreground`/`palette` block in `ghostty/.config/ghostty/config` (for Catppuccin, replace it with the built-in `theme = Catppuccin Mocha`) |
| tmux    | hex colors in `tmux/.tmux.conf` (pane borders, status bar, active tab)          |
| yazi    | `[flavor]` in `yazi/.config/yazi/theme.toml` (flavors vendored in `flavors/`)   |
| lazygit | `gui.theme` block in `lazygit/.config/lazygit/config.yml`                       |
| delta   | `syntax-theme` + `[include]` in `git/.config/git/config`; bat theme in `bat/.config/bat/themes/` (then `bat cache --build`) |

lazygit/delta/bat currently only vendor tokyonight (copied from tokyonight.nvim's `extras/`); a Catppuccin switch needs catppuccin/lazygit, catppuccin/delta and catppuccin/bat assets added.

Catppuccin notes for the next switch: the mocha background is darkened one step from stock — ghostty gets `background = 181825` (mantle) and catppuccin.nvim shifts base→mantle→crust down via `color_overrides` so terminal and editor match; tmux's inactive pane border then wants crust (`#11111b`). The catppuccin.nvim spec in `colorscheme.lua` must keep its `lazy = false` + explicit `config` that re-applies the scheme after `setup(opts)`: LazyVim applies the colorscheme before plugin configs run, and catppuccin's argless-setup fallback would otherwise compile the default palette and silently drop the overrides on every startup.

## tmux: Claude Code usage + tab colors

The right side of the status bar shows Claude Code plan usage for the 5-hour and weekly windows (`5h ▓▓░░░ 42% · 2 hr  wk ▓░░░░ 18% · 4 days`), and window tabs recolor by Claude state: orange = working, red = wants input, cleared when finished. No API calls — Claude Code pipes a JSON blob (incl. `rate_limits` on Pro/Max logins) to its `statusLine` command on every render.

The Claude Code half lives in the `claude` package:

- `~/.claude/statusline.sh` renders the in-Claude status line (`model · effort · context %`, the percentage green/yellow/red at 50/80 %) and writes the usage numbers to `~/.cache/claude-usage/usage`. Wired up via `statusLine` in `~/.claude/settings.json`.
- `hooks` in `~/.claude/settings.json` (`UserPromptSubmit`/`PostToolUse` → orange, `Notification` → red, `Stop`/`SessionStart`/`SessionEnd` → clear) color the tab with `tmux set-window-option -t "$TMUX_PANE" window-status-style`.

`settings.json` itself is not stowed: it also holds machine-local plugins and preferences, and Claude Code rewrites it. Its `statusLine` and `hooks` keys are kept in `claude/.claude/settings.tmux.json`; merge them in once after stowing (this replaces any existing `statusLine`/`hooks` keys wholesale):

```bash
jq -s '.[0] * .[1]' ~/.claude/settings.json ~/.claude/settings.tmux.json > /tmp/settings.json \
  && mv /tmp/settings.json ~/.claude/settings.json
```

If you change the hooks in `settings.json`, copy them back into `settings.tmux.json` so the repo stays in sync.

The tmux half: `tmux/.local/bin/tmux-claude-usage` reads the cache and prints the segment (pure bash, runs every `status-interval`), and `tmux/.tmux.conf` calls it from `status-right` and carries the `after-select-window` hook that clears a red tab when you visit it (Claude's idle notification lands ~60 s after `Stop`, so without it red would stick on idle sessions).

Constraints: `window-status-format` must have no `fg=` pin or it overrides the hook color. The orange `#ff9e64` and red `#f7768e` must stay paired between the settings.json hooks and the `after-select-window` match pattern. Numbers refresh only while some Claude session is rendering on this machine; API-key/Bedrock/Team sessions don't receive `rate_limits`, so the segment stays empty there. `statusline.sh` needs `jq`; the tmux script is pure bash.

## Yazi: yank to system clipboard (macOS)

`y` in yazi copies selected files to the macOS clipboard as file references, so ⌘V into Finder/Mail/Slack pastes the actual files.

```bash
brew install clippy
```

The reverse also works: `<C-v>` pastes files copied in Finder into the current directory (`yazi/.config/yazi/scripts/paste-clipboard.sh`). `C` zips the selection into a timestamped `archive-*.zip`.

The keymap bindings are in `yazi/.config/yazi/keymap.toml`; the plugin itself is **vendored** at `yazi/.config/yazi/plugins/clippy.yazi/` (tracked via the un-ignore in `yazi/.config/yazi/.gitignore`), so `stow yazi/` is all it takes — no `ya pkg install`.

It started life as the `ya pkg` dep `Gallardo994/clippy`, but that repo is unmaintained and broke on yazi 26.x: `cx.yanked` now yields `File` userdata instead of `Url`, so the plugin's `tostring(u)` produced `File: 0x…` pointer strings, passed those to `clippy` as filenames, and the clipboard silently kept its previous contents. The fork takes `u.url` instead. Keeping it out of `package.toml` means a `ya pkg upgrade` can't restore the broken upstream copy over it.

## Yazi: Dropbox online-only indicator (macOS)

Online-only Dropbox files are 0-byte placeholder stubs on disk (classic sync engine, not File Provider) — so any empty regular file swaps its icon for a cyan `☁` and gets a `☁` marker on the right. Purely size-based: instant, no per-directory scanning, works through any symlinked route; genuinely empty files (e.g. `.gitkeep`) show a harmless false `☁`. Either indicator can be disabled in `init.lua`: `setup { icon = false }` / `setup { linemode = false }`. The `☁` clears once a file becomes available offline.

Downloading/eviction stays in Finder (right-click → *Make Available Offline* / *Online Only*): the classic engine has no silent programmatic trigger — `open`ing a stub downloads it, but then also opens it. `g o` reveals the hovered file/folder in Finder to make that a two-keystroke detour. Implemented in `yazi/.config/yazi/plugins/dropbox-cloud.yazi`.

## Neovim extras

**File references for a terminal AI split.** `<leader>yp` yanks `@path` and `<leader>yl` yanks `@path:line` (or `@path:start-end` in visual mode) to the clipboard, for pasting a file reference into a CLI assistant running in a neighbouring Ghostty split (`cmd+d`). Paths are relative to the directory nvim was launched from; the capitalised variants `<leader>yP` / `<leader>yL` yank absolute paths. Harmless if you don't use one.

**Markdown table rows.** `<leader>mr` shows the table row under the cursor in a float, one `Header / value` pair per column with long cells wrapped (`lua/table_row.lua`).

**`.docx` editing.** A local plugin (`lua/docx/`, loaded from `lua/plugins/docx.lua`) opens `.docx` files as editable text and writes changes back into the original document surgically, preserving the formatting; `:DocxRevert` restores the file to how it was when opened (from a backup), `:DocxReload` re-reads it from disk. Needs `python3 -m pip install --user python-docx`.

**tmux scrollback in nvim.** The `prefix ]` capture keeps SGR colors, strips other control sequences, and renders the result with baleia.nvim (`lua/config/ansi_capture.lua`).
