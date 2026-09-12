# dotfiles

Shell configuration for macOS and Linux, with the secrets kept out of the repo and out of
every file on disk.

```sh
git clone https://github.com/chi-feng/dotfiles ~/dotfiles && ~/dotfiles/install.sh
```

The installer symlinks `~/.zshenv`, `~/.zshrc`, and `~/.zprofile` (and `~/.gitconfig` on
macOS), creates `~/.config/zsh/local.zsh` from the example, and moves any existing real
file to a dated backup under `~/.local/state`.

## Layout

| Path | Purpose |
|---|---|
| `zsh/.zshenv` | Environment for every zsh: PATH, the secrets loader, and the local file |
| `zsh/.zshrc` | Interactive setup: Oh My Zsh, completions, helpers, the Claude Code launcher |
| `zsh/.zprofile` | Login-shell PATH and app aliases |
| `zsh/local.zsh.example` | Template for `~/.config/zsh/local.zsh`, the private per-machine file |
| `bin/secrets` | Manage the secret store (`list`, `get`, `set`, `edit`, `export`, `json`) |
| `bin/with-secret` | Run one command with a break-glass value and log the use |
| `claude/bash-env.sh` | Hands the Anthropic key to Claude Code's Bash tool only |

## Secrets

`secrets` keeps two `KEY=value` blobs in the OS secret store: `main`, which `.zshenv`
exports into every shell, and `breakglass`, which only `with-secret` reads. On macOS the
store is the login Keychain, read through `/usr/bin/security`, so the load never prompts
and works from a launchd job or a remote session. On Linux the store is a mode-0600 file
under `~/.config/secrets`.

```sh
secrets edit                          # everyday keys, opens $EDITOR
secrets set FOO_API_KEY < value.txt   # one entry, value on stdin
secrets get FOO_API_KEY               # one value, for scripts that run outside a shell
with-secret PROD_TOKEN -- ./deploy.sh # a break-glass value for one command
```

Hostnames, profiles, and ssh aliases that are private but not secret go in
`~/.config/zsh/local.zsh`, which the repo never sees.

## Claude Code

The `claude` function starts the CLI without `ANTHROPIC_API_KEY` in its environment, so
the claude.ai login stays primary and claude.ai connectors keep working, and it points
`CLAUDE_ENV_FILE` at `claude/bash-env.sh`, which exports the key for Bash tool commands
that call the Anthropic SDK. The `claude_*` functions select a model, effort, and
permission mode.
