# Claude Code sources this file before Bash tool commands when CLAUDE_ENV_FILE points
# at it (the claude launcher in zsh/.zshrc sets that). The CLI process itself runs
# without the Console key so the claude.ai login stays primary, and commands that call
# the Anthropic SDK still find the key here. Keep the last line a command, not a comment.
export ANTHROPIC_API_KEY="$("$HOME/dotfiles/bin/secrets" get ANTHROPIC_API_KEY 2>/dev/null)"
