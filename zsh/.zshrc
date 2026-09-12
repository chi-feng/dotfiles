# Interactive zsh. Environment and secrets load in .zshenv, and machine-local values live
# in ~/.config/zsh/local.zsh. Nothing in this file is secret.

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="zhann"
plugins=(git)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Tools that install outside the package manager.
export BUN_INSTALL="$HOME/.bun"
for _d in "$HOME/.cache/lm-studio/bin" "$HOME/.antigravity/antigravity/bin" "$HOME/go/bin" "$BUN_INSTALL/bin"; do
  [[ -d "$_d" ]] && case ":$PATH:" in *":$_d:"*) ;; *) export PATH="$_d:$PATH" ;; esac
done
unset _d
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

export COREPACK_ENABLE_AUTO_PIN=0
export PYTHONUNBUFFERED=1

# >>> npm-security-lockdown >>>
export NPM_CONFIG_IGNORE_SCRIPTS=true
export PNPM_ENABLE_PRE_POST_SCRIPTS=false
export YARN_ENABLE_SCRIPTS=false
# <<< npm-security-lockdown <<<

# `uv run <file>` completes Python files.
_uv_run_mod() {
  if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
    _arguments '*:filename:_files -g "*.py"'
  else
    _uv "$@"
  fi
}
(( $+functions[compdef] )) && compdef _uv_run_mod uv

# AWS SSO: `alog <profile>` logs in and selects that profile for this shell.
alog() {
  local profile="$1"
  if [ -z "$profile" ]; then
    echo "Usage: alog <profile>"
    return 1
  fi
  export AWS_PROFILE="$profile"
  export AWS_SDK_LOAD_CONFIG=1
  aws sso login --profile "$profile"
}
_alog_profiles() {
  local -a profiles
  profiles=($(aws configure list-profiles 2>/dev/null))
  _describe 'aws profiles' profiles
}
(( $+functions[compdef] )) && compdef _alog_profiles alog

# Claude Code. The launcher removes the Console API key from the CLI process so the
# claude.ai login stays primary (connectors, remote control), and hands the key back to
# Bash tool commands through CLAUDE_ENV_FILE. A managed-preferences plist can pin model
# and effort above settings.json, and a CLI flag still wins. Quote [1m]: zsh globs a bare one.
export CLAUDE_CODE_NO_FLICKER=1
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0  # teammates flood the lead with idle pings (claude-code#73647)
claude()        { env -u ANTHROPIC_API_KEY CLAUDE_ENV_FILE="$DOTFILES/claude/bash-env.sh" claude "$@"; }
claude_fable()  { claude --model "fable[1m]"  --effort xhigh --permission-mode auto "$@"; }
claude_opus()   { claude --model "opus[1m]"   --effort xhigh --permission-mode auto "$@"; }
claude_sonnet() { claude --model "sonnet[1m]" --effort high  --permission-mode auto "$@"; }
claude_haiku()  { claude --model haiku --permission-mode auto "$@"; }
claude_plan()   { claude --model "fable[1m]"  --effort xhigh --permission-mode plan "$@"; }
claude_dsp()    { claude --dangerously-skip-permissions "$@"; }

# Codex CLI in the terminal uses its own profile so its MCP credentials stay separate
# from the ChatGPT desktop app.
codex() { command codex --profile cli "$@"; }
