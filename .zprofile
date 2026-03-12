if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]]; then
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fi

if [[ -d "/Applications/Obsidian.app/Contents/MacOS" ]]; then
  export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
fi
