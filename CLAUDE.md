@README.md

## Notes for agents

- Every top-level directory is a GNU Stow package mirroring `$HOME` (e.g. `nvim/.config/nvim/` → `~/.config/nvim/`). Files at the repo root (`README.md`, `CLAUDE.md`, `.gitignore`) are not stowed. A package that targets a directory where apps write state (`~/.claude`, `~/.local`) must never be folded into a whole-directory symlink; keep the `mkdir -p` in the README install step in sync when adding such a package.
- When you add, remove or change a feature, update `README.md` in the same change. It is the single source of context for this repo.
- This repo is **public**. Never commit secrets, tokens, emails, hostnames, absolute `/Users/...` paths or other personal information. Identity and credentials stay in the unstowed `~/.gitconfig`. `~/.claude/settings.json` is not stowed (machine-local plugins); only its `statusLine`/`hooks` keys are mirrored in `claude/.claude/settings.tmux.json`.
