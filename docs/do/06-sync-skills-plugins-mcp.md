# Sync skills, plugins, instructions and MCP

You get one source per concern in your box notes, applied with vendor commands, so every harness sees the same skills and instructions, there are no duplicate copies, and no file holds a literal token.

## Goal

Each of skills, plugins, instructions, MCP servers and model pins has one source in your box notes. Re-running the steps below changes nothing.

## Before you start

- [do/04](04-install-agent-harnesses.md) is done.
- Your box notes are cloned on the box at `<notes-dir>`.
- Copy [skills.txt](../../examples/skills.txt), [claude-settings.fragment.json](../../examples/claude-settings.fragment.json) and [codex-config.fragment.toml](../../examples/codex-config.fragment.toml) into `<notes-dir>` and edit them there. Never edit the copies in this repo for your own use.

## Steps

### 1. Keep one source per concern

| Artifact | Source in box notes | Harnesses that read it | Apply command |
| --- | --- | --- | --- |
| Skills | `skills.txt` | Codex, Cursor and OpenCode read `~/.agents/skills`; Claude Code reads symlinks in `~/.claude/skills` | `npx skills add ... -g` |
| Claude plugins | `claude-settings.fragment.json` | Claude Code on the box; desktop app sessions load the box's `enabledPlugins` plus the device's plugins | `jq` merge |
| Codex plugins | `codex-config.fragment.toml` plus marketplace commands | Codex | `codex plugin marketplace add` |
| Instructions | `AGENTS.md` | Claude Code by import; Codex; OpenCode; Cursor (project `AGENTS.md` only) | import line or symlink |
| MCP servers | per-harness entries | each harness | vendor command |
| Model pins | fragments | each harness | merge |

Leave these out of sync on purpose:

- Account-synced Claude content (`~/.claude/skills/synced`): the account owns it.
- Runtime state: `~/.claude.json` apart from its MCP entries, `~/.claude/plugins/known_marketplaces.json`, `~/.claude/plugins/installed_plugins.json`, `~/.claude/remote`, Codex `[projects.*]` tables and marketplace `last_revision` values.
- Caches: plugin caches and build caches.

### 2. Install skills from a manifest

`skills.txt` has one line per source: `<owner/repo> [--skill <name>]`. Blank lines and `#` comments are ignored. Apply it with a loop:

```bash
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  src=${line%% *}
  args=${line#"$src"}
  npx skills add "$src" $args -g -y -a claude-code </dev/null
done < <notes-dir>/skills.txt
```

The `</dev/null` matters: without it `npx` reads the rest of the manifest from standard input and the loop stops after the first line. Update installed skills with:

```bash
npx skills update -g -y
```

Install each skill set through one channel only: the skills CLI, a plugin, or a vendor CLI that writes skills. Never two.

Observed (as of 2026-09, `skills` 1.7.0): `npx skills add -g` writes one canonical copy under `~/.agents/skills` and links it only into the agent directories selected at install time. A run without `-a` linked skills to Codex, Cursor, GitHub Copilot, OpenCode and Zed but not to Claude Code, so the loop passes `-a claude-code` (`-a, --agent <agents>` in `npx skills add --help`); the ones that read `~/.agents/skills` natively need no link. Whether one `-a` accepts several agents is Unverified; repeat the flag or run one `-a` per agent if needed. `~/.claude/skills` then holds relative symlinks into `~/.agents/skills`. Codex reads `~/.agents/skills` ([docs](https://learn.chatgpt.com/docs/build-skills)); Cursor and OpenCode document reading it too ([Cursor](https://cursor.com/docs/context/skills), [OpenCode](https://opencode.ai/docs/skills/)). The `vercel-labs/skills` README lists other paths per agent, so confirm with `npx skills list -g`.

The global lock `~/.agents/.skill-lock.json` records sources but has no documented restore, so it is not a restore source; your manifest is. `npx skills experimental_install` restores only a project's `skills-lock.json`. Unverified (as of 2026-09): whether a future release restores the global lock.

A skill is a directory with a `SKILL.md` whose frontmatter requires `name` (lowercase, hyphens, matching the directory) and `description` ([spec](https://agentskills.io/specification)).

### 3. Declare Claude plugins in settings

Put `extraKnownMarketplaces` and `enabledPlugins` in the fragment, then merge it into the live settings. Back up first. In `jq`, `*` deep-merges objects and replaces arrays:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq -s '.[0] * .[1]' ~/.claude/settings.json <notes-dir>/claude-settings.fragment.json > /tmp/settings.json \
  && mv /tmp/settings.json ~/.claude/settings.json
```

Documented (as of 2026-09): Claude Code registers declared marketplaces and installs enabled plugins at the next session start ([plugins](https://code.claude.com/docs/en/plugins/org), [marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)). Set `CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1` so headless `claude -p` runs wait for the install. The docs describe managed and project scope; that user scope behaves the same is assumed.

The imperative equivalent:

```bash
claude plugin marketplace add <owner/repo>
claude plugin install <plugin>@<marketplace>
```

Observed (as of 2026-09): imperative installs drift from the declared set, so a box can register more marketplaces than its settings declare. Prefer the fragment.

Desktop app sessions load the box's `enabledPlugins` and also the plugins enabled in the desktop app on the device (Observed, as of 2026-09). A plugin removed from the box can still arrive from a device, so apply the same fragment on each device.

### 4. Add Codex plugins

```bash
codex plugin marketplace list
codex plugin marketplace add <owner/repo>
codex plugin add <plugin>@<marketplace>
```

Enable a plugin in `~/.codex/config.toml`:

```toml
[plugins."<plugin>@<marketplace>"]
enabled = true
```

Run `codex plugin marketplace list` first: whether re-adding an existing marketplace is safe is Unverified (as of 2026-09).

### 5. Share one instructions core

Keep `AGENTS.md` in `<notes-dir>`. Make `~/.claude/CLAUDE.md` start with the import line, then add Claude-only notes below it:

```markdown
@<notes-dir>/AGENTS.md
```

Use an `@AGENTS.md` import to share the core with Claude Code. Documented (as of 2026-09): a symlinked `CLAUDE.md` also works in CLI sessions, but Cowork desktop sessions skip a symlinked `~/.claude/CLAUDE.md` and skip user-scope imports that resolve outside the session's working directory, so the `@<notes-dir>/AGENTS.md` line loads nothing there ([memory docs](https://code.claude.com/docs/en/memory)). If you use Cowork, keep the core inside the working directory or accept that it does not load in those sessions.

Link the core for the other harnesses:

```bash
mkdir -p ~/.codex ~/.config/opencode
ln -sf <notes-dir>/AGENTS.md ~/.codex/AGENTS.md
ln -sf <notes-dir>/AGENTS.md ~/.config/opencode/AGENTS.md
```

Documented (as of 2026-09): OpenCode reads `~/.config/opencode/AGENTS.md` and falls back to `~/.claude/CLAUDE.md` when it is absent ([rules](https://opencode.ai/docs/rules/)). Unverified: whether Codex reads a symlinked `~/.codex/AGENTS.md`. If it does not, copy the file instead and compare with `cmp <notes-dir>/AGENTS.md ~/.codex/AGENTS.md`. Cursor reads only a project's `AGENTS.md`, so keep one in each repo.

### 6. Configure MCP servers per harness

MCP has no shared config format (Observed, as of 2026-09).

| Harness | Where | How |
| --- | --- | --- |
| Claude Code | `mcpServers` in `~/.claude.json`, user scope | `claude mcp add --scope user <name> -- <command>`; for a remote server `claude mcp add --scope user --transport http <name> <url>`, then authorize with `/mcp` |
| Codex | `[mcp_servers.<name>]` in `~/.codex/config.toml` | edit the table, or `codex mcp add <name> -- <command>`; OAuth with `codex mcp login <name>` |
| Cursor | `mcpServers` in `~/.cursor/mcp.json` | edit the file |
| OpenCode | `mcp` key in `opencode.json` | `type` is `local` or `remote`; `command` is an array; `{env:VAR}` substitutes an environment variable |

Never template `~/.claude.json`: it mixes user-scope MCP entries with large runtime state and caches. Add servers through the command.

Rule: use OAuth, or reference environment variable names. Never write a literal token or an authorization header into any of these files. The [Codex fragment](../../examples/codex-config.fragment.toml) shows a server with no secrets.

### 7. Pin models with your own values

Model values are yours and live only in box notes. This guide names the keys, not the values.

| Harness | File | Keys |
| --- | --- | --- |
| Claude Code | `~/.claude/settings.json` | `model`, `availableModels`, `enforceAvailableModels`, `effortLevel`; env entries `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL` |
| Codex | `~/.codex/config.toml` | `model`, `model_catalog_json` |
| OpenCode | `opencode.json` | `model`, `small_model`, `agent.<name>.model` |
| Cursor Agent | `~/.cursor/cli-config.json` | `model`, `selectedModel` (Observed, as of 2026-09) |

Desktop apps choose a model per session, so a pin on the box does not constrain them.

### 8. Update

```bash
npx skills update -g -y
codex plugin marketplace upgrade
```

After you edit a fragment, run its merge again.

## Check

Every `skills.txt` entry is installed, and no link is broken:

```bash
npx skills list -g
find ~/.claude/skills -xtype l
```

```bash
npx skills list -g --json | jq -r '.[] | select(.agents | index("Claude Code") | not) | .name'
```

Expected: the list shows every skill from your manifest; `find` prints nothing; the `jq` command prints no skill that Claude Code should see. The `agents` field name and the `Claude Code` label are Observed (as of 2026-09).

Plugins are present:

```bash
claude plugin list
codex plugin marketplace list
```

Expected: `claude plugin list` shows each `enabledPlugins` entry; the Codex list shows each marketplace you added.

The instructions import resolves:

```bash
head -1 ~/.claude/CLAUDE.md
```

Expected: the `@<notes-dir>/AGENTS.md` line, and that file exists.

No literal auth headers (counts only; never print matching lines, they may hold secrets):

```bash
grep -ciE 'authorization|bearer ' ~/.codex/config.toml ~/.cursor/mcp.json
```

Expected: `0` per file. A missing file is fine.

Claude Code keeps MCP entries, including any header added with `claude mcp add --header`, in `~/.claude.json`. Count header names that look like credentials, without printing values:

```bash
jq '[.mcpServers // {} | .[] | .headers // {} | keys[] | select(test("authorization";"i"))] | length' ~/.claude.json
```

Expected: `0`. Use OAuth or an environment variable name instead; for Codex the env-var-name form is `--bearer-token-env-var`.

No skill is a real copy in more than one place:

```bash
ls ~/.agents/skills ~/.codex/skills ~/.cursor/skills ~/.config/opencode/skills 2>/dev/null | sort | uniq -d
```

Expected: no skill name is printed unless the other locations hold only symlinks. Confirm any printed name with `ls -ld` on each path: at most one may be a directory that is not a symlink.

## Needs a human

- Plugin and workspace trust prompts.
- OAuth logins for MCP servers.
- Re-trusting Codex hooks in an interactive `codex` session after a hooks file changes (Observed, as of 2026-09).
- Cursor plugins: no declarative mechanism was found (Unverified, as of 2026-09), so import them through the Cursor UI.
