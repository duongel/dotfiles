#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZSH_CONFIG_DIR="$XDG_CONFIG_HOME/zsh"
GIT_CONFIG_DIR="$XDG_CONFIG_HOME/git"
LOCAL_SHARE_BIN="$HOME/.local/bin"

link_file() {
  local source_path="$1"
  local target_path="$2"
  local target_dir

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    return
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    mv "$target_path" "${target_path}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  ln -s "$source_path" "$target_path"
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

load_homebrew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Homebrew is not available after installation." >&2
    exit 1
  fi
}

install_brew_packages() {
  brew update
  brew bundle --file "$REPO_DIR/Brewfile"
}

install_oh_my_zsh() {
  local zsh_dir="$HOME/.local/share/oh-my-zsh"
  local custom_dir="$zsh_dir/custom"

  if [[ ! -d "$zsh_dir/.git" ]]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
  fi

  mkdir -p "$custom_dir/themes" "$custom_dir/plugins"

  if [[ ! -d "$custom_dir/themes/powerlevel10k/.git" ]]; then
    git clone https://github.com/romkatv/powerlevel10k.git \
      "$custom_dir/themes/powerlevel10k"
  fi

  if [[ ! -d "$custom_dir/plugins/zsh-autosuggestions/.git" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "$custom_dir/plugins/zsh-autosuggestions"
  fi
}

install_fonts() {
  mkdir -p "$HOME/Library/Fonts"
  cp -f "$REPO_DIR"/fonts/*.ttf "$HOME/Library/Fonts/"
}

configure_nvm() {
  local nvm_prefix

  nvm_prefix="$(brew --prefix nvm)"
  mkdir -p "$HOME/.nvm"

  if [[ -f "$nvm_prefix/nvm.sh" ]]; then
    link_file "$nvm_prefix/nvm.sh" "$HOME/.nvm/nvm.sh"
  fi

  if [[ -f "$nvm_prefix/etc/bash_completion.d/nvm" ]]; then
    link_file "$nvm_prefix/etc/bash_completion.d/nvm" "$HOME/.nvm/bash_completion"
  fi
}

configure_symlinks() {
  mkdir -p "$ZSH_CONFIG_DIR/completion" "$GIT_CONFIG_DIR" "$XDG_CACHE_HOME" \
    "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$LOCAL_SHARE_BIN"

  link_file "$REPO_DIR/.zshenv" "$HOME/.zshenv"
  link_file "$REPO_DIR/.zshrc" "$ZSH_CONFIG_DIR/.zshrc"
  link_file "$REPO_DIR/.zprofile" "$ZSH_CONFIG_DIR/.zprofile"
  link_file "$REPO_DIR/.p10k.zsh" "$ZSH_CONFIG_DIR/.p10k.zsh"
  link_file "$REPO_DIR/.fzf.zsh" "$ZSH_CONFIG_DIR/.fzf.zsh"
  link_file "$REPO_DIR/.nanorc" "$HOME/.nanorc"
  link_file "$REPO_DIR/.aliases" "$HOME/.aliases"
  link_file "$REPO_DIR/.macos" "$HOME/.macos"
  link_file "$REPO_DIR/.gitignore_global" "$GIT_CONFIG_DIR/ignore"

  git config --global core.excludesfile "$GIT_CONFIG_DIR/ignore"
}

ensure_default_shell() {
  local zsh_path

  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    echo "zsh is not installed or not on PATH." >&2
    exit 1
  fi

  if ! grep -qx "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
  fi
}

apply_macos_defaults() {
  bash "$REPO_DIR/.macos"
}

main() {
  install_homebrew
  load_homebrew
  install_brew_packages
  install_oh_my_zsh
  install_fonts
  configure_nvm
  configure_symlinks
  ensure_default_shell
  apply_macos_defaults

  echo "Bootstrap complete. Restart Terminal or run 'exec zsh'."
}

main "$@"
