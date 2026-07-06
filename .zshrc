export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export LESSHISTFILE="$XDG_STATE_HOME/lesshst"
export _Z_DATA="$XDG_STATE_HOME/z"
export SHELL_SESSIONS_DISABLE=1
unset GIT_PAGER

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Locale and editors
export LANG="en_GB.UTF-8"
export EDITOR="nano"
export VISUAL="nano"

# nvm: lazy load, damit zsh-Start schnell bleibt
export NVM_DIR="$XDG_CONFIG_HOME/nvm"

_lazy_nvm() {
  unset -f nvm node npm npx
  [ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"
  nvm "$@"
}

nvm() { _lazy_nvm "$@"; }
node() { _lazy_nvm node "$@"; }
npm()  { _lazy_nvm npm  "$@"; }
npx()  { _lazy_nvm npx  "$@"; }

# Tool and shell configuration
export ZSH="$XDG_DATA_HOME/oh-my-zsh"
export DOCKER_HOST="unix://$XDG_CONFIG_HOME/colima/default/docker.sock"
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="/var/run/docker.sock"
if [[ -z "${TESTCONTAINERS_HOST_OVERRIDE:-}" ]] \
  && [[ -S "$XDG_CONFIG_HOME/colima/default/docker.sock" ]]; then
  _colima_cache="$XDG_CACHE_HOME/colima-ip"
  _colima_sock="$XDG_CONFIG_HOME/colima/default/docker.sock"
  if [[ ! -f "$_colima_cache" || "$_colima_sock" -nt "$_colima_cache" ]]; then
    command -v colima >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
      && colima ls -j 2>/dev/null | jq -r 'if type == "array" then (.[0].address // empty) else (.address // empty) end' > "$_colima_cache"
  fi
  [[ -s "$_colima_cache" ]] && export TESTCONTAINERS_HOST_OVERRIDE="$(<"$_colima_cache")"
  unset _colima_cache _colima_sock
fi

# load NODE_AUTH_TOKEN
[ -f "$XDG_CONFIG_HOME/github/github.env" ] && source "$XDG_CONFIG_HOME/github/github.env"

fpath=($XDG_DATA_HOME/zsh/completions $fpath)

ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(sudo git docker z brew docker-compose gh kubectl mvn zsh-autosuggestions)

source "$ZSH/oh-my-zsh.sh"

fcd() {
  local dir
  dir=$((echo ".."; find ${1:-.} -type d -not -path '*/\.*') 2> /dev/null | fzf +m) && cd "$dir"
}

# Git shortcuts
alias gd="git pull"
alias glog='git log -n 5 --oneline --format="$(tput setaf 2)%h$(tput sgr0) $(tput setaf 3)%ad$(tput sgr0) $(tput setaf 4)%an$(tput sgr0) $(tput setaf 5)%d$(tput sgr0) %s" --date=format:"%Y-%m-%d %H:%M:%S"'
alias gs="git status"
alias gu="git push"

# Tooling shortcuts
alias ls="eza"
alias npmi="npm install"
alias playwright-local-ui="npx playwright test --project local --ui"
alias kk="k9s"

# Global shell shortcuts
alias -g hh="~/"

expand_git_commit_shortcut() {
  if [[ "$LBUFFER" == *'gca' ]]; then
    LBUFFER="${LBUFFER%gca}git add . && git commit -am \"fix: \""
    CURSOR=$((CURSOR - 1))
  elif [[ "$LBUFFER" == *'gc' ]]; then
    LBUFFER="${LBUFFER%gc}git commit -m \"fix: \""
    CURSOR=$((CURSOR - 1))
  else
    zle self-insert
  fi
}

zle -N git-commit-shortcuts expand_git_commit_shortcut
bindkey ' ' git-commit-shortcuts

# Plugin and prompt setup
[ -f "$XDG_CONFIG_HOME/zsh/.fzf.zsh" ] && source "$XDG_CONFIG_HOME/zsh/.fzf.zsh"
bindkey '^ ' autosuggest-accept

# Keyboard-only prompt selection in terminals such as Ghostty.
_select_region_start() {
  if (( ! REGION_ACTIVE )); then
    MARK=$CURSOR
    REGION_ACTIVE=1
  fi
}

_select_backward_char() { _select_region_start; zle backward-char; }
_select_forward_char() { _select_region_start; zle forward-char; }
_select_backward_word() { _select_region_start; zle backward-word; }
_select_forward_word() { _select_region_start; zle forward-word; }

zle -N select-backward-char _select_backward_char
zle -N select-forward-char _select_forward_char
zle -N select-backward-word _select_backward_word
zle -N select-forward-word _select_forward_word

bindkey $'\e[1;2D' select-backward-char
bindkey $'\e[1;2C' select-forward-char
bindkey $'\e[1;4D' select-backward-word
bindkey $'\e[1;4C' select-forward-word

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f "$XDG_CONFIG_HOME/zsh/.p10k.zsh" ]] || source "$XDG_CONFIG_HOME/zsh/.p10k.zsh"

# Load machine-specific or private overrides after shared defaults so they can
# add aliases, hooks, and function overrides without forking this public file.
[ -f "$XDG_CONFIG_HOME/zsh/private.local.zsh" ] && source "$XDG_CONFIG_HOME/zsh/private.local.zsh"

# BEGIN vp-digital-abschluss-frontend-devtools
_DEVTOOLS_PROJECT_DIR="${HOME}/Documents/vp-digital-abschluss-frontend"
_DEVTOOLS_ACTIVATE="${HOME}/Documents/vp-digital-abschluss-frontend-devtools/activate.sh"

_devtools_chpwd() {
  if [[ "${PWD}" == "${_DEVTOOLS_PROJECT_DIR}" ||         "${PWD}" == "${_DEVTOOLS_PROJECT_DIR}/"* ]]; then
    if [[ -z "${_DEVTOOLS_ORIGINAL_PATH:-}" && -f "${_DEVTOOLS_ACTIVATE}" ]]; then
      source "${_DEVTOOLS_ACTIVATE}"
    fi
  else
    if [[ -n "${_DEVTOOLS_ORIGINAL_PATH:-}" ]]; then
      deactivate-devtools
    fi
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _devtools_chpwd
# END vp-digital-abschluss-frontend-devtools

. "$HOME/.local/share/../bin/env"
