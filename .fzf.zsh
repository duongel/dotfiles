for prefix in /opt/homebrew /usr/local; do
  if [[ -f "$prefix/opt/fzf/shell/completion.zsh" ]]; then
    source "$prefix/opt/fzf/shell/completion.zsh"
  fi

  if [[ -f "$prefix/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "$prefix/opt/fzf/shell/key-bindings.zsh"
  fi
done
