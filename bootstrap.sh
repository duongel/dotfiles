#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/bootstrap.log"
RESTART_APPS_AFTER_BOOTSTRAP=0
INSTALL_WORK_TOOLS=""
LINK_ZSH_CONFIG=""
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZSH_CONFIG_DIR="$XDG_CONFIG_HOME/zsh"
GIT_CONFIG_DIR="$XDG_CONFIG_HOME/git"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"
WORK_STATE_FILE="$DOTFILES_CONFIG_DIR/work"
ZSH_LINK_STATE_FILE="$DOTFILES_CONFIG_DIR/zshrc-link"
LOCAL_SHARE_BIN="$HOME/.local/bin"
PRIVATE_ZSH_FILE="$ZSH_CONFIG_DIR/private.local.zsh"

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

copy_repo_file() {
  local source_path="$1"
  local target_path="$2"
  local target_dir

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"

  if [[ -L "$target_path" ]]; then
    mv "$target_path" "${target_path}.bak.$(date +%Y%m%d%H%M%S)"
  elif [[ -e "$target_path" ]]; then
    echo "Keeping existing $target_path untouched. Compare it with $source_path manually."
    return
  fi

  cp "$source_path" "$target_path"
  echo "Copied $source_path to $target_path."
}

install_zsh_config_file() {
  local source_path="$1"
  local target_path="$2"

  if zsh_config_is_linked; then
    symlink_repo_file "$source_path" "$target_path"
  else
    copy_repo_file "$source_path" "$target_path"
  fi
}

read_stored_choice() {
  local state_file="$1"

  if [[ -r "$state_file" ]]; then
    head -n 1 "$state_file"
  fi
}

ask_yes_no() {
  local question="$1"
  local default_answer="$2"
  local answer

  if [[ ! -t 0 ]]; then
    echo "No interactive terminal attached. Using default: $default_answer." >&2
    printf '%s\n' "$default_answer"
    return
  fi

  if [[ "$default_answer" == "yes" ]]; then
    echo "$question [Y/n]" >&2
  else
    echo "$question [y/N]" >&2
  fi

  IFS= read -r answer || answer=""
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) printf 'yes\n' ;;
    [Nn]|[Nn][Oo]) printf 'no\n' ;;
    "") printf '%s\n' "$default_answer" ;;
    *)
      echo "Unrecognised answer '$answer'. Using default: $default_answer." >&2
      printf '%s\n' "$default_answer"
      ;;
  esac
}

work_tools_are_installed() {
  command -v mvn >/dev/null 2>&1 || command -v az >/dev/null 2>&1 \
    || [[ -d "$XDG_CONFIG_HOME/nvm" || -d "$HOME/.nvm" ]]
}

decide_on_work_tools() {
  local stored_choice
  local default_choice

  if [[ -n "$INSTALL_WORK_TOOLS" ]]; then
    echo "Work-related tools: ${INSTALL_WORK_TOOLS} (from command line)."
    return
  fi

  stored_choice="$(read_stored_choice "$WORK_STATE_FILE")"
  if [[ "$stored_choice" == "enabled" || "$stored_choice" == "disabled" ]]; then
    default_choice="$stored_choice"
  elif work_tools_are_installed; then
    # Machine bootstrapped before work tools became optional.
    default_choice="enabled"
  else
    default_choice="disabled"
  fi

  if [[ "$(ask_yes_no "Install work-related tools (azure-cli, nvm, maven) and work zsh config?" \
    "$(choice_to_yes_no "$default_choice" enabled)")" == "yes" ]]; then
    INSTALL_WORK_TOOLS="enabled"
  else
    INSTALL_WORK_TOOLS="disabled"
  fi

  echo "Work-related tools: $INSTALL_WORK_TOOLS."
}

choice_to_yes_no() {
  local choice="$1"
  local yes_value="$2"

  if [[ "$choice" == "$yes_value" ]]; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

decide_on_zsh_config_symlinks() {
  local stored_choice
  local default_choice

  if [[ -n "$LINK_ZSH_CONFIG" ]]; then
    echo "zsh config handling: ${LINK_ZSH_CONFIG} (from command line)."
    return
  fi

  stored_choice="$(read_stored_choice "$ZSH_LINK_STATE_FILE")"
  if [[ "$stored_choice" == "linked" || "$stored_choice" == "copied" ]]; then
    default_choice="$stored_choice"
  else
    default_choice="linked"
  fi

  echo "Symlinking $ZSH_CONFIG_DIR/.zshrc to $REPO_DIR/.zshrc keeps this host in sync with the"
  echo "repository, so local edits can be committed and pushed from $REPO_DIR."
  echo "Declining copies the file instead; an existing .zshrc is then left untouched."

  if [[ "$(ask_yes_no "Symlink .zshrc (and zsh/work.zsh) to this repository?" \
    "$(choice_to_yes_no "$default_choice" linked)")" == "yes" ]]; then
    LINK_ZSH_CONFIG="linked"
  else
    LINK_ZSH_CONFIG="copied"
  fi

  echo "zsh config handling: $LINK_ZSH_CONFIG."
}

zsh_config_is_linked() {
  [[ "$LINK_ZSH_CONFIG" == "linked" ]]
}

work_tools_enabled() {
  [[ "$INSTALL_WORK_TOOLS" == "enabled" ]]
}

persist_choices() {
  mkdir -p "$DOTFILES_CONFIG_DIR"
  echo "$INSTALL_WORK_TOOLS" > "$WORK_STATE_FILE"
  echo "$LINK_ZSH_CONFIG" > "$ZSH_LINK_STATE_FILE"
  echo "Recorded choices in $WORK_STATE_FILE and $ZSH_LINK_STATE_FILE."
}

install_required_brew_packages() {
  require_writable_directory "$(brew --prefix)/Cellar" "Homebrew Cellar"
  require_writable_directory "$(brew --prefix)/Caskroom" "Homebrew Caskroom"

  install_brew_bundle "$REPO_DIR/Brewfile"

  if work_tools_enabled; then
    install_brew_bundle "$REPO_DIR/Brewfile.work"
  else
    echo "Skipping work-related brew packages."
  fi
}

install_brew_bundle() {
  local brewfile="$1"

  if brew bundle check --file "$brewfile" >/dev/null 2>&1; then
    echo "Homebrew bundle already satisfied: $brewfile"
    return
  fi

  brew bundle --file "$brewfile" --no-upgrade
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

  if ! work_tools_enabled; then
    echo "Skipping nvm setup because work-related tools are disabled."
    return
  fi

  if ! brew list nvm >/dev/null 2>&1; then
    echo "nvm is not installed via Homebrew. Skipping nvm setup."
    return
  fi

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
    "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$LOCAL_SHARE_BIN" "$DOTFILES_CONFIG_DIR"

  symlink_repo_file "$REPO_DIR/.zshenv" "$HOME/.zshenv"
  install_zsh_config_file "$REPO_DIR/.zshrc" "$ZSH_CONFIG_DIR/.zshrc"
  install_zsh_config_file "$REPO_DIR/zsh/work.zsh" "$ZSH_CONFIG_DIR/work.zsh"
  symlink_repo_file "$REPO_DIR/.zprofile" "$ZSH_CONFIG_DIR/.zprofile"
  symlink_repo_file "$REPO_DIR/.p10k.zsh" "$ZSH_CONFIG_DIR/.p10k.zsh"
  symlink_repo_file "$REPO_DIR/.fzf.zsh" "$ZSH_CONFIG_DIR/.fzf.zsh"
  symlink_repo_file "$REPO_DIR/.nanorc" "$HOME/.nanorc"
  symlink_repo_file "$REPO_DIR/.aliases" "$HOME/.aliases"
  symlink_repo_file "$REPO_DIR/.macos" "$HOME/.macos"
  symlink_repo_file "$REPO_DIR/.gitignore_global" "$GIT_CONFIG_DIR/ignore"

  git config --global core.excludesfile "$GIT_CONFIG_DIR/ignore"

  report_zshrc_state
}

report_zshrc_state() {
  local target="$ZSH_CONFIG_DIR/.zshrc"

  if ! zsh_config_is_linked; then
    echo "$target is a standalone copy. Edit $REPO_DIR/.zshrc and re-run bootstrap.sh to update it."
    return
  fi

  if [[ -L "$target" && "$(readlink "$target")" == "$REPO_DIR/.zshrc" ]]; then
    echo "$target -> $REPO_DIR/.zshrc (edits can be committed from $REPO_DIR)."
    return
  fi

  echo "Failed to link $target to $REPO_DIR/.zshrc." >&2
  exit 1
}

set_zsh_as_default_shell() {
  local zsh_path
  local current_shell

  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    echo "zsh is not installed or not on PATH." >&2
    exit 1
  fi

  if ! grep -qx "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    echo "Login shell is already $zsh_path."
    return
  fi

  chsh -s "$zsh_path"
}

apply_macos_settings() {
  bash "$REPO_DIR/.macos"
}

import_private_zsh_config() {
  local source_path
  local resolved_source
  local temp_file

  if [[ ! -t 0 ]]; then
    echo "Skipping private zsh config import because no interactive terminal is attached."
    return
  fi

  mkdir -p "$ZSH_CONFIG_DIR"

  if [[ -f "$PRIVATE_ZSH_FILE" ]]; then
    echo "Private zsh config already exists at $PRIVATE_ZSH_FILE."
    return
  fi

  echo "Optional private zsh config path (leave empty to skip):"
  IFS= read -r source_path

  if [[ -z "$source_path" ]]; then
    echo "Skipped private zsh config import."
    return
  fi

  if [[ "$source_path" == ~* ]]; then
    eval "resolved_source=\"$source_path\""
  else
    resolved_source="$source_path"
  fi

  if [[ ! -f "$resolved_source" ]]; then
    echo "Private zsh config not found: $resolved_source" >&2
    return
  fi

  temp_file="$(mktemp)"
  {
    echo "# Imported by bootstrap.sh on $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# Source: $resolved_source"
    printf '\n'
    cat "$resolved_source"
    printf '\n'
  } > "$temp_file"
  mv "$temp_file" "$PRIVATE_ZSH_FILE"

  echo "Imported private zsh config to $PRIVATE_ZSH_FILE."
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
      --work)
        INSTALL_WORK_TOOLS="enabled"
        ;;
      --no-work)
        INSTALL_WORK_TOOLS="disabled"
        ;;
      --link-zshrc)
        LINK_ZSH_CONFIG="linked"
        ;;
      --no-link-zshrc)
        LINK_ZSH_CONFIG="copied"
        ;;
      *)
        echo "Unknown argument: $1" >&2
        echo "Usage: ./bootstrap.sh [--restart-apps] [--work|--no-work] [--link-zshrc|--no-link-zshrc]" >&2
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

  run_step "choosing whether to install work-related tools" decide_on_work_tools
  run_step "choosing how to install the zsh config" decide_on_zsh_config_symlinks
  run_step "installing homebrew" ensure_homebrew_is_installed
  run_step "loading homebrew into the shell" load_homebrew_into_shell
  run_step "installing required brew packages" install_required_brew_packages
  run_step "installing oh-my-zsh, powerlevel10k and zsh-autosuggestions" install_zsh_framework_and_plugins
  run_step "installing terminal fonts" install_terminal_fonts
  run_step "linking nvm files" link_homebrew_nvm_files
  run_step "creating xdg symlinks" create_xdg_symlinks
  run_step "recording bootstrap choices" persist_choices
  run_step "setting zsh as the default shell" set_zsh_as_default_shell
  run_step "importing private zsh config" import_private_zsh_config
  run_step "applying macos settings" apply_macos_settings

  restart_affected_apps
  echo "Bootstrap finished. Restart Terminal or run 'exec zsh'."
  echo "==== bootstrap finished $(date '+%Y-%m-%d %H:%M:%S') ===="
}

acquire_sudo() {
  printf '%s\n' "Administrator privileges are required for some steps." \
                 "You may be prompted for your password."
  if ! sudo -v 2>&1; then
    echo "Failed to obtain sudo access." >&2
    exit 1
  fi
  # Keep sudo timestamp refreshed in background until this script exits
  (
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null
      sleep 50
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

parse_args "$@"
acquire_sudo
main 2>&1 | write_log_with_timestamps
exit "${PIPESTATUS[0]}"
