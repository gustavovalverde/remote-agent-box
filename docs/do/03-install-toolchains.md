# Install toolchains

You get the build tools your projects and agents need (Node, optionally Rust, Docker Engine, git and GitHub auth), installed once for your user.

## Goal

Toolchains installed for `<user>`, Docker publishing to loopback by default, git identity set, GitHub authenticated, and a routine to keep disk in check.

## Before you start

[do/02](02-lock-down-the-network.md) is done, so `/etc/docker/daemon.json` already exists (see [examples/docker-daemon.json](../../examples/docker-daemon.json)).

## Steps

### 1. Node.js

Install the current LTS line from NodeSource, then enable corepack. `npx` is needed for `npx skills` in [do/06](06-sync-skills-plugins-mcp.md). Check NodeSource's docs for the current LTS script name.

```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo corepack enable
```

### 2. Rust (if your projects use it)

```bash
sudo apt-get install -y clang lld pkg-config libssl-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
cargo binstall -y sccache cargo-nextest
cargo install cargo-sweep --locked
```

Leave rust-analyzer to the editor that manages it ([why](../learn/how-it-works.md#leave-a-tools-managed-defaults-alone-until-you-know-why-they-exist)).

### 3. Docker Engine

Install `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin` and `docker-compose-plugin` from Docker's apt repository, following [Docker's install docs](https://docs.docker.com/engine/install/ubuntu/). Then:

```bash
sudo usermod -aG docker <user>
```

Log out and back in. Long-lived agent daemons keep their old groups, and reconnecting an app does not refresh them, so restart them too ([why and how](../learn/how-it-works.md#new-group-membership-needs-a-fresh-login)).

### 4. Git and GitHub

```bash
git config --global user.name "<your name>"
git config --global user.email "<id>+<username>@users.noreply.github.com"
gh auth login
```

Use your GitHub noreply address so commit metadata never carries a private email. `gh auth login` is a hand-off.

### 5. Headless browser for agents (optional)

```bash
npx playwright install --with-deps chromium
```

Unverified (as of 2026-09): not run on a reference box.

### 6. Keep disk in check

```bash
df -h /
docker system df
docker builder prune
cargo sweep --time 30 <project-dir>   # Rust target directories
```

Run these when `df` shows the disk more than 70 percent full.

## Check

```bash
node -v && corepack --version           # both print versions
rustc -V                                # prints a version if you installed Rust
ssh <box> 'id -nG' | grep -qw docker && echo ok   # ok; a fresh login, not this process
sg docker -c 'docker run --rm -d -p 18080:80 --name bindcheck nginx:alpine && docker port bindcheck; docker rm -f bindcheck'
                                        # 80/tcp -> 127.0.0.1:18080
gh auth status                          # logged in
git config --global user.email          # ends in users.noreply.github.com
```

The `docker port` line is the expected format; it is Unverified on a reference box (as of 2026-09).

## Needs a human

`gh auth login`: the browser or device-code step.
