# Back up the box

You get encrypted, scheduled, offsite backups of agent config, box notes, mesh identity and project secrets, plus a restore you have actually tested.

## Goal

Encrypted, scheduled, offsite backups you have restored from at least once.

## Before you start

- An offsite storage target (decision 8 in [choose-your-setup](../decide/choose-your-setup.md)).
- A password manager for the restic repository password.
- restic installed: `sudo apt-get install -y restic`, or see the [restic docs](https://restic.readthedocs.io/en/stable/020_installation.html).
- This recipe follows restic's documentation and is Unverified end to end on a reference box (as of 2026-09). Your restore test in step 6 is the proof that it works.

## Steps

### 1. Decide what to back up

Include:

- Agent config: `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.claude.json`, `~/.codex/config.toml`, `~/.codex/AGENTS.md`, `~/.cursor/mcp.json`, `~/.config/opencode`.
- Login stores: `~/.claude/.credentials.json`, `~/.codex/auth.json`, `~/.config/cursor/auth.json` ([do/04](04-install-agent-harnesses.md#5-sign-in)). Alternatively exclude them and sign in again after a restore; choose one and record it.
- Your box notes, including the skills manifest. Back up the manifest, not the skills store.
- Mesh identity: `/var/lib/tailscale/tailscaled.state` (on Tailscale).
- Project secret files.

Exclude caches and runtime state: `~/.claude/remote`, plugin caches, build targets, container images.

Write the list to a root-only file, for example `/etc/restic/include.txt` and `/etc/restic/exclude.txt`. Use absolute paths such as `/home/<user>/.claude/settings.json`: restic does not expand `~`, and the root service would read it as root's home. Every path above is written this way in the file.

### 2. Give project secrets one encrypted home

The backup, or your password manager, holds project secrets. Once they are in it, delete plaintext copies elsewhere in `$HOME`.

### 3. Initialize the repository

Create `/etc/restic/env` with mode 600, owned by root, holding the variable names `RESTIC_REPOSITORY` and `RESTIC_PASSWORD_FILE` (and your storage provider's credential variables, per restic's docs for your backend). Then:

```bash
sudo install -d -m 700 /etc/restic
sudo sh -c 'set -a; . /etc/restic/env; restic init'
```

### 4. Schedule it

A system service and timer run as root so they can read `tailscaled.state`.

`/etc/systemd/system/restic-backup.service`:

```ini
[Unit]
Description=restic backup

[Service]
Type=oneshot
EnvironmentFile=/etc/restic/env
ExecStart=/usr/bin/restic backup --files-from /etc/restic/include.txt --exclude-file /etc/restic/exclude.txt
```

`/etc/systemd/system/restic-backup.timer`:

```ini
[Unit]
Description=Daily restic backup

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now restic-backup.timer
```

### 5. Prune on a schedule

Add a second service and timer pair (same pattern, weekly) running:

```bash
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

### 6. Test a restore

Restore one agent-config file and the mesh state, using absolute paths (`<file>` is such a path, for example `/home/<user>/.claude/settings.json`):

```bash
sudo sh -c 'set -a; . /etc/restic/env; restic restore latest --target /tmp/restore-test --include <file> --include /var/lib/tailscale/tailscaled.state'
sudo diff <file> /tmp/restore-test<file>
sudo test -s /tmp/restore-test/var/lib/tailscale/tailscaled.state && echo ok
```

Repeat after any change to the include list. Restoring `tailscaled.state` to keep the box's mesh identity after a rebuild is Unverified; re-joining the mesh and re-applying the ACL tag is the fallback.

### 7. Before wiping or rebuilding

Find work that exists only on the box, then run a manual backup:

```bash
for r in <repos-dir>/*/; do
  git -C "$r" status --porcelain | grep -q . && echo "uncommitted: $r"
  [ -n "$(git -C "$r" log --branches --not --remotes --oneline)" ] && echo "unpushed: $r"
done
sudo systemctl start restic-backup.service
```

## Check

```bash
systemctl list-timers restic-backup.timer                                    # shows a next run
sudo sh -c 'set -a; . /etc/restic/env; restic snapshots --latest 1'          # a snapshot from the last 24 hours
sudo sh -c 'set -a; . /etc/restic/env; restic check'                         # no errors
sudo diff <file> /tmp/restore-test<file>                                     # prints nothing (an agent-config file)
sudo test -s /tmp/restore-test/var/lib/tailscale/tailscaled.state && echo ok  # ok (mesh state)
```

## Needs a human

- Creating the storage account and credentials.
- Storing the restic password in a password manager.
