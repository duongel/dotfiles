# dotfiles repository

On a new Mac:

```sh
git clone https://github.com/duongel/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew packages required by `.zshrc`, sets up XDG-style symlinks for zsh and git, installs Oh My Zsh with `powerlevel10k` and `zsh-autosuggestions`, installs the Meslo Nerd Fonts, sets `zsh` as the default shell, and applies `.macos`.

All dotfiles are symlinked from this repository. For `~/.config/zsh/.zshrc` and `~/.config/zsh/work.zsh` the symlink is optional and `bootstrap.sh` asks for it:

* **symlink** (default) — editing the shell config on any host edits `~/Documents/dotfiles/.zshrc`, so the change can be committed and pushed from there. An existing file is backed up as `<name>.bak.<timestamp>` first.
* **copy** — the host gets a standalone copy that never changes again by itself. An already existing `.zshrc` is left untouched.

The answer is stored in `~/.config/dotfiles/zshrc-link` (`linked` or `copied`) and can be preset with `--link-zshrc` / `--no-link-zshrc`. All other dotfiles are always symlinked.

## Work-related tools

Work tooling is optional. `bootstrap.sh` asks whether it should be installed and remembers the answer in `~/.config/dotfiles/work` (`enabled` or `disabled`):

| Part | Personal | Work |
| --- | --- | --- |
| Homebrew packages | `Brewfile` | `Brewfile.work` (azure-cli, nvm, maven) |
| zsh config | `.zshrc` | `zsh/work.zsh` (nvm lazy loading, `NODE_AUTH_TOKEN`, npm/playwright aliases, work project hooks, oh-my-zsh plugin `mvn`) |

Non-interactive or scripted runs:

```sh
./bootstrap.sh --work           # install work tooling without asking
./bootstrap.sh --no-work        # skip work tooling without asking
./bootstrap.sh --clear-dock     # wipe all app icons from the Dock without asking
./bootstrap.sh --no-clear-dock  # keep the current Dock without asking
```

All questions can be skipped entirely, for example `./bootstrap.sh --no-work --link-zshrc --no-clear-dock`. Without a TTY, the stored or detected defaults are used.

Running `.macos` standalone asks the Dock question itself; set `CLEAR_DOCK=yes` or `CLEAR_DOCK=no` to skip it.

The choice can be changed later by re-running `bootstrap.sh`, by editing `~/.config/dotfiles/work`, or per shell with `DOTFILES_WORK=1` / `DOTFILES_WORK=0`. Re-running with `--no-work` only stops the work config from loading; already installed brew packages are not removed.

Machines set up before work tooling became optional keep working after a `git pull`: when `~/.config/dotfiles/work` is missing, `.zshrc` enables the work config as soon as `mvn`, `az`, or an nvm directory is present.

## App configuration

`init/BetterTouchTool/default.bttpreset` is imported during `bootstrap.sh` (after the cask is installed). The step asks first, then launches BetterTouchTool and imports the preset through its AppleScript interface (`import_preset`), so no manual confirmation is needed. Terminal (or whichever app runs the script) needs automation permission for BetterTouchTool; macOS asks for it on the first run. If scripting is unavailable, the preset is opened in BetterTouchTool instead and has to be confirmed in its dialog. The preset's checksum is stored in `~/.config/dotfiles/bettertouchtool-preset` after a successful import, so re-runs do nothing until the preset in the repository actually changes.

The other directories under `init/` (Sublime Text, terminal profiles) are still imported manually.

## Re-running

`bootstrap.sh` is idempotent: with the same answers a second run changes nothing. Brew bundles are checked before installing, clones and symlinks are skipped when already correct (no new `.bak` files), the login shell is only changed when it actually differs, and an existing `~/.config/zsh/private.local.zsh` is never overwritten. `.macos` re-applies its `defaults` settings on every run, which converges to the same state. Only changing an answer causes work: switching from `linked` to `copied` (or back) replaces the file and backs the previous one up.

Symlinks that already point at the repository file are only refreshed, never backed up, even if the link path is spelled differently, and dangling symlinks are replaced instead of being backed up. `bootstrap.sh` and `.macos` resolve their own location through symlinks, so running `~/.macos` (the symlink created by `bootstrap.sh`) targets the repository and not `$HOME`. Piping either script into `bash` is rejected because the repository location cannot be determined that way.

In `copied` mode a re-run does **not** refresh an existing `~/.config/zsh/.zshrc`; it is reported instead so local modifications survive. Delete the copy first if you want the repository version back.

## Private overrides

Private machine-specific aliases, SSH shortcuts, internal project paths, and similar local-only settings should go into `~/.config/zsh/private.local.zsh`. During `./bootstrap.sh`, you can optionally provide the path to an existing private zsh file and its contents will be imported into that local override file automatically.
