# ~/.zshenv runs for every zsh, interactive or not, so it carries only environment.
# Interactive setup (prompt, completions, aliases, functions) lives in .zshrc.

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"   # uv puts ~/.local/bin on PATH

export DOTFILES="${DOTFILES:-$HOME/dotfiles}"
case ":$PATH:" in *":$DOTFILES/bin:"*) ;; *) export PATH="$DOTFILES/bin:$PATH" ;; esac

# Secrets load once per process tree as KEY=value lines from the OS store: the macOS
# login Keychain item "shell-env", or ~/.config/secrets/shell-env on Linux. Child shells
# inherit the exports and skip the read. Manage the store with bin/secrets.
if [[ -z "$SHELL_ENV_LOADED" ]]; then
  _v=""
  case "$OSTYPE" in
    darwin*) _v="$(/usr/bin/security find-generic-password -a "${USER:-$(id -un)}" -s shell-env -w 2>/dev/null | base64 -d 2>/dev/null)" ;;
    *) [[ -r "$HOME/.config/secrets/shell-env" ]] && _v="$(<"$HOME/.config/secrets/shell-env")" ;;
  esac
  if [[ -n "$_v" ]]; then
    while IFS= read -r _line; do [[ "$_line" == [A-Za-z_]*=* ]] && export "$_line"; done <<< "$_v"
    export SHELL_ENV_LOADED=1
  fi
  unset _v _line
fi

# Machine-local, private, non-secret settings (hosts, profiles, aliases). Not in the repo.
[[ -r "$HOME/.config/zsh/local.zsh" ]] && source "$HOME/.config/zsh/local.zsh"
