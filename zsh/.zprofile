# Login shells: package-manager PATH and a few macOS app aliases.

[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[[ -d "$HOME/Library/Python/3.9/bin" ]] && export PATH="$HOME/Library/Python/3.9/bin:$PATH"
[[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]] && alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
[[ -x /opt/homebrew/bin/python3.10 ]] && alias python=/opt/homebrew/bin/python3.10

# >>> npm-security-lockdown >>>
export NPM_CONFIG_IGNORE_SCRIPTS=true
export PNPM_ENABLE_PRE_POST_SCRIPTS=false
export YARN_ENABLE_SCRIPTS=false
# <<< npm-security-lockdown <<<
