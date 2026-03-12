#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/bootstrap.log"
RESTART_APPS_AFTER_BOOTSTRAP=0
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZSH_CONFIG_DIR="$XDG_CONFIG_HOME/zsh"
GIT_CONFIG_DIR="$XDG_CONFIG_HOME/git"
LOCAL_SHARE_BIN="$HOME/.local/bin"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
if [[ -s "$LOG_FILE" ]]; then
  printf '\n' >> "$LOG_FILE"
fi

write_log_with_timestamps() {
  /usr/bin/python3 -u -c '
import sys
from datetime import datetime

log_path = sys.argv[1]

with open(log_path, "a", buffering=1) as log_file:
    for raw_line in sys.stdin:
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        line = raw_line[:-1] if raw_line.endswith("\n") else raw_line
        formatted = f"{timestamp} {line}\n"
        log_file.write(formatted)
        sys.stdout.write(formatted)
' "$LOG_FILE"
}

require_writable_directory() {
  local path="$1"
  local description="$2"

  if [[ ! -d "$path" ]]; then
    echo "Expected directory missing: $path ($description)" >&2
    exit 1
  fi

  if [[ ! -w "$path" ]]; then
    echo "Cannot write to $path ($description)." >&2
    echo "This usually means the bootstrap is running inside a sandboxed terminal session." >&2
    echo "Run ./bootstrap.sh in a normal local terminal with full disk access, or grant the session elevated filesystem access." >&2
    exit 1
  fi
}

run_step() {
  local step_label="$1"
  shift

  echo "==> START: $step_label"
  "$@"
  echo "==> DONE:  $step_label"
}

symlink_repo_file() {
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

ensure_homebrew_is_installed() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

load_homebrew_into_shell() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Homebrew is not available after installation." >&2
    exit 1
  fi
}

install_required_brew_packages() {
  require_writable_directory "$(brew --prefix)/Cellar" "Homebrew Cellar"
  require_writable_directory "$(brew --prefix)/Caskroom" "Homebrew Caskroom"

  if brew bundle check --file "$REPO_DIR/Brewfile" >/dev/null 2>&1; then
    echo "Homebrew bundle already satisfied."
    return
  fi

  brew bundle --file "$REPO_DIR/Brewfile" --no-upgrade
}

install_zsh_framework_and_plugins() {
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

install_terminal_fonts() {
  require_writable_directory "$HOME/Library/Fonts" "user font directory"
  mkdir -p "$HOME/Library/Fonts"
  cp -f "$REPO_DIR"/fonts/*.ttf "$HOME/Library/Fonts/"
}

link_homebrew_nvm_files() {
  local nvm_prefix

  nvm_prefix="$(brew --prefix nvm)"
  mkdir -p "$HOME/.nvm"

  if [[ -f "$nvm_prefix/nvm.sh" ]]; then
    symlink_repo_file "$nvm_prefix/nvm.sh" "$HOME/.nvm/nvm.sh"
  fi

  if [[ -f "$nvm_prefix/etc/bash_completion.d/nvm" ]]; then
    symlink_repo_file "$nvm_prefix/etc/bash_completion.d/nvm" "$HOME/.nvm/bash_completion"
  fi
}

create_xdg_symlinks() {
  mkdir -p "$ZSH_CONFIG_DIR/completion" "$GIT_CONFIG_DIR" "$XDG_CACHE_HOME" \
    "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$LOCAL_SHARE_BIN"

  symlink_repo_file "$REPO_DIR/.zshenv" "$HOME/.zshenv"
  symlink_repo_file "$REPO_DIR/.zshrc" "$ZSH_CONFIG_DIR/.zshrc"
  symlink_repo_file "$REPO_DIR/.zprofile" "$ZSH_CONFIG_DIR/.zprofile"
  symlink_repo_file "$REPO_DIR/.p10k.zsh" "$ZSH_CONFIG_DIR/.p10k.zsh"
  symlink_repo_file "$REPO_DIR/.fzf.zsh" "$ZSH_CONFIG_DIR/.fzf.zsh"
  symlink_repo_file "$REPO_DIR/.nanorc" "$HOME/.nanorc"
  symlink_repo_file "$REPO_DIR/.aliases" "$HOME/.aliases"
  symlink_repo_file "$REPO_DIR/.macos" "$HOME/.macos"
  symlink_repo_file "$REPO_DIR/.gitignore_global" "$GIT_CONFIG_DIR/ignore"

  git config --global core.excludesfile "$GIT_CONFIG_DIR/ignore"
}

set_zsh_as_default_shell() {
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

apply_macos_settings() {
  bash "$REPO_DIR/.macos"
}

restart_affected_apps() {
  if [[ "$RESTART_APPS_AFTER_BOOTSTRAP" -ne 1 ]]; then
    echo "Skipped restarting apps. Re-run with --restart-apps if you want affected apps relaunched automatically."
    return
  fi

  echo "Restarting affected apps now."
  for app in "Activity Monitor" "Brave Browser" "Calendar" "Contacts" "cfprefsd" \
    "Dock" "Finder" "Mail" "Messages" \
    "Opera" "Safari" "SizeUp" "Spectacle" "SystemUIServer" "Terminal" "Tower" \
    "Transmission"; do
    killall "${app}" > /dev/null 2>&1
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --restart-apps)
        RESTART_APPS_AFTER_BOOTSTRAP=1
        ;;
      *)
        echo "Unknown argument: $1" >&2
        echo "Usage: ./bootstrap.sh [--restart-apps]" >&2
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  echo "==== bootstrap started $(date '+%Y-%m-%d %H:%M:%S') ===="
  echo "Repo: $REPO_DIR"
  echo "Log:  $LOG_FILE"

  run_step "installing homebrew" ensure_homebrew_is_installed
  run_step "loading homebrew into the shell" load_homebrew_into_shell
  run_step "installing required brew packages" install_required_brew_packages
  run_step "installing oh-my-zsh, powerlevel10k and zsh-autosuggestions" install_zsh_framework_and_plugins
  run_step "installing terminal fonts" install_terminal_fonts
  run_step "linking nvm files" link_homebrew_nvm_files
  run_step "creating xdg symlinks" create_xdg_symlinks
  run_step "setting zsh as the default shell" set_zsh_as_default_shell
  run_step "applying macos settings" apply_macos_settings

  restart_affected_apps
  echo "Bootstrap finished. Restart Terminal or run 'exec zsh'."
  echo "==== bootstrap finished $(date '+%Y-%m-%d %H:%M:%S') ===="
}

parse_args "$@"
main 2>&1 | write_log_with_timestamps
exit "${PIPESTATUS[0]}"
