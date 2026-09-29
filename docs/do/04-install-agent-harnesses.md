# Install agent harnesses

You get the harnesses you chose installed once each from the vendor channel, signed in, with approvals on and relay channels off. You also learn where each login lives, by name.

## Goal

Every chosen harness runs on the box, updates itself from one channel, and holds a login. Approvals are on. No relay channel is enabled.

## Before you start

- [do/01](01-provision-the-host.md) to [do/03](03-install-toolchains.md) are done: you can SSH to `<box>` over the mesh, and `git`, `curl`, `jq` and Node.js are installed.
- You picked your harnesses and billing in [choose your setup](../decide/choose-your-setup.md#6-harnesses-and-billing).
- You install each harness through one channel only. Two installs of the same harness put two binaries on `PATH`, and the wrong one wins after an update.

Run every command below on the box, in an SSH session.

## Steps

Install commands are worked examples (as of 2026-09). Vendors change installer URLs, so follow the linked vendor page if a command fails.

### 1. Claude Code

Use the vendor installer ([vendor docs](https://code.claude.com/docs/en/setup)):

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude update
```

The Claude desktop app installs its own copy on the box when it first connects ([do/05](05-connect-clients.md#3-claude-desktop-app)). Install the CLI here anyway if you want the CLI over SSH.

### 2. Codex

Use the standalone installer ([vendor docs](https://developers.openai.com/codex/cli)):

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex update
```

Remove any older package-manager install (for example an npm global) so only one `codex` is on `PATH`:

```bash
type -ap codex | xargs -r -n1 readlink -f | sort -u
```

The command resolves every `codex` on `PATH` and removes duplicates, because `PATH` can repeat a directory and `/bin` can be a symlink to `/usr/bin`. Observed (as of 2026-09): a stale npm-global Codex sat beside the standalone install and was shadowed on `PATH`. If the command prints more than one path, remove the extra copy with the tool that installed it (for example `npm uninstall -g @openai/codex`), then run `hash -r`.

### 3. Cursor Agent CLI (optional)

Use the vendor installer ([vendor docs](https://cursor.com/docs/cli/overview)):

```bash
curl https://cursor.com/install -fsS | bash
```

The command is `cursor-agent`. Newer vendor docs call it `agent`; the installer creates both names as links to the same binary (Observed, as of 2026-09).

### 4. OpenCode (optional, for API keys or gateways)

OpenCode suits API keys and gateways, and cannot use a Claude subscription login ([why](../decide/choose-your-setup.md#opencode-cannot-use-a-claude-subscription)). Use the vendor installer ([vendor docs](https://opencode.ai/docs/)); it is Unverified on a reference box (as of 2026-09):

```bash
curl -fsSL https://opencode.ai/install | bash
```

`opencode serve` is unsecured without a password ([security model](../learn/security-model.md#relay-channels-bypass-the-mesh)). Keep it on loopback, set the password, and reach it through an SSH tunnel:

```bash
OPENCODE_SERVER_PASSWORD="$(cat <secret-file>)" opencode serve
# on the device:
ssh -L 4096:127.0.0.1:4096 <box>
opencode attach http://127.0.0.1:4096 --password "$(cat <secret-file>)"
```

Keep the password in a file with mode 600 or a secret manager, never inline, so it stays out of shell history. `--password` and `--username` are the documented attach flags ([CLI docs](https://opencode.ai/docs/cli/)); the device needs its own copy of the secret.

Do not pass `--hostname 0.0.0.0`. Record any wider bind as an [exception](../learn/security-model.md#recording-an-exception).

### 5. Sign in

Each login is a hand-off. Run the command, follow the browser or device-code prompt, and return.

| Harness | Command | Login stored in (name only) |
| --- | --- | --- |
| Claude Code | `claude`, then `/login` | `~/.claude/.credentials.json` |
| Codex | `codex login` | `~/.codex/auth.json` |
| Cursor Agent | `cursor-agent login` (shows a QR code you can scan over SSH) | `~/.config/cursor/auth.json` |
| OpenCode | `opencode auth login` | `~/.local/share/opencode/auth.json` |

The store paths are Observed (as of 2026-09) for Claude Code, Codex and Cursor, and Documented for OpenCode ([providers docs](https://opencode.ai/docs/providers/)). Cursor's `~/.cursor/cli-config.json` holds the account email and model settings, not tokens. Treat all four login files as secrets: they belong in your [backups](07-back-up.md) (see the include list there) and nowhere else. Never paste their contents into a chat, an issue or a repo.

Also sign in to GitHub if [do/03](03-install-toolchains.md) did not:

```bash
gh auth login
```

### 6. Keep approvals on

Approvals are the prompts a harness shows before it runs commands or edits files. Leave them on.

- Claude Code: leave `permissions.defaultMode` unset in `~/.claude/settings.json`, or set it to anything except `bypassPermissions`. Do not start sessions with `--dangerously-skip-permissions`.
- Codex: leave `approval_policy` and `sandbox_mode` at their defaults in `~/.codex/config.toml`. Do not use `approval_policy = "never"` with `sandbox_mode = "danger-full-access"`, or `--dangerously-bypass-approvals-and-sandbox`.

Turning approvals off is an exception you [record](../learn/security-model.md#recording-an-exception); the trade-off is in the [security model](../learn/security-model.md#harness-approvals).

### 7. Leave relay channels off

Leave `remoteControlAtStartup` false or unset in `~/.claude/settings.json`; the starter fragment [claude-settings.fragment.json](../../examples/claude-settings.fragment.json) sets it to false. Leave `crossSessionInbound` unset too, and do not run `codex remote-control start` or `codex app-server daemon enable-remote-control`. Enable any relay only as a recorded exception ([relay channels](../learn/security-model.md#relay-channels-bypass-the-mesh)).

### 8. Choose models

Model choice is your own. Config key names and where they live are in [do/06, Pin models with your own values](06-sync-skills-plugins-mcp.md#7-pin-models-with-your-own-values).

## Check

Versions print for every harness you installed:

```bash
claude --version
codex --version
cursor-agent --version
```

Expected: one version line each. Skip the Cursor line if you did not install it.

Exactly one Codex on `PATH`:

```bash
type -ap codex | xargs -r -n1 readlink -f | sort -u
```

Expected: exactly one resolved path.

Approvals are not off:

```bash
jq -r '.permissions.defaultMode // "unset"' ~/.claude/settings.json
grep -cE '^(approval_policy *= *"never"|sandbox_mode *= *"danger-full-access")' ~/.codex/config.toml
```

Expected: the first prints `unset` or a mode other than `bypassPermissions`; the second prints `0`. If `~/.codex/config.toml` does not exist yet, the second command reports a missing file, which is also fine.

Relay channel is off:

```bash
jq -r '.remoteControlAtStartup // false' ~/.claude/settings.json
```

Expected: `false`.

```bash
jq -r '.crossSessionInbound // "unset"' ~/.claude/settings.json
ps -eo args | grep -c '[r]emote-control'
```

Expected: `unset` (or `false`) and `0`.

Codex login mode (reads one key, never the tokens):

```bash
jq -r '.auth_mode' ~/.codex/auth.json
```

Expected: `chatgpt` for a subscription login. An API key login prints a different mode.

The key names `permissions.defaultMode` and `remoteControlAtStartup` come from the vendor settings docs and a working box; treat the exact key spelling as Unverified for versions released after 2026-09.

## Needs a human

- Every login in step 5: a browser or device-code step.
- Choosing plans, and creating API keys in provider consoles.
- Approving the desktop app's first SSH connection ([do/05](05-connect-clients.md)).
