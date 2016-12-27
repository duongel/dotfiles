# dotfiles repository

On a new Mac:

```sh
git clone <repo-url> ~/Documents/dotfiles
cd ~/Documents/dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew packages required by `.zshrc`, sets up XDG-style symlinks for zsh and git, installs Oh My Zsh with `powerlevel10k` and `zsh-autosuggestions`, installs the Meslo Nerd Fonts, sets `zsh` as the default shell, and applies `.macos`.

Private machine-specific aliases, SSH shortcuts, internal project paths, and similar local-only settings should go into `~/.config/zsh/private.local.zsh`. During `./bootstrap.sh`, you can optionally provide the path to an existing private zsh file and its contents will be imported into that local override file automatically.
