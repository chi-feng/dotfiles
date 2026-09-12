#!/usr/bin/env bash
# Symlink the dotfiles into $HOME. An existing real file moves to a dated backup directory.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backup="$HOME/.local/state/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

link() {
  local src="$DOTFILES/$1" dst="$HOME/$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok      $dst"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$backup"; chmod 700 "$backup"
    mv "$dst" "$backup/$2"
    echo "moved   $dst -> $backup/$2"
  fi
  ln -s "$src" "$dst"
  echo "linked  $dst -> $src"
}

link zsh/.zshenv .zshenv
link zsh/.zshrc .zshrc
link zsh/.zprofile .zprofile
[[ "$OSTYPE" == darwin* ]] && link git/.gitconfig .gitconfig

mkdir -p "$HOME/.config/zsh" "$HOME/.config/secrets" "$HOME/.local/state/secrets"
chmod 700 "$HOME/.config/secrets" "$HOME/.local/state/secrets"
if [[ ! -f "$HOME/.config/zsh/local.zsh" ]]; then
  cp "$DOTFILES/zsh/local.zsh.example" "$HOME/.config/zsh/local.zsh"
  chmod 600 "$HOME/.config/zsh/local.zsh"
  echo "created $HOME/.config/zsh/local.zsh from the example"
fi
chmod +x "$DOTFILES/bin/"* "$DOTFILES/install.sh"
echo "done: open a new shell, then run 'secrets list' to check the secret store"
