# Work-related shell configuration.
#
# Sourced from .zshrc only when work tooling (azure-cli, nvm, maven) is enabled;
# see $XDG_CONFIG_HOME/dotfiles/work, written by bootstrap.sh, or DOTFILES_WORK=1.
# Every block guards its own dependencies so the file stays harmless when a
# tool is missing.

# nvm: lazy load so zsh startup stays fast.
export NVM_DIR="$XDG_CONFIG_HOME/nvm"

_lazy_nvm() {
  unset -f nvm node npm npx
  local nvm_script="$NVM_DIR/nvm.sh"
  if [[ ! -s "$nvm_script" ]] && command -v brew >/dev/null 2>&1; then
    nvm_script="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
  fi
  [ -s "$nvm_script" ] && . "$nvm_script"
  "$@"
}

nvm() { _lazy_nvm nvm "$@"; }
node() { _lazy_nvm node "$@"; }
npm()  { _lazy_nvm npm  "$@"; }
npx()  { _lazy_nvm npx  "$@"; }

# load NODE_AUTH_TOKEN
[ -f "$XDG_CONFIG_HOME/github/github.env" ] && source "$XDG_CONFIG_HOME/github/github.env"

# Node tooling shortcuts
alias npmi="npm install"
alias playwright-local-ui="npx playwright test --project local --ui"

# BEGIN vp-digital-abschluss-frontend-devtools
_DEVTOOLS_PROJECT_DIR="${HOME}/Documents/vp-digital-abschluss-frontend"
_DEVTOOLS_ACTIVATE="${HOME}/Documents/vp-digital-abschluss-frontend-devtools/activate.sh"

_devtools_chpwd() {
  if [[ "${PWD}" == "${_DEVTOOLS_PROJECT_DIR}" || "${PWD}" == "${_DEVTOOLS_PROJECT_DIR}/"* ]]; then
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
