# Provision the box

You get a clean, updated box you can SSH into with a key as your own user, with security updates on and no surprise reboots.

## Goal

A box with enough disk, SSH with your key as your own user, base packages, security updates that never reboot on their own, and systemd-logind set to keep user processes after logout.

## Before you start

- A provider account.
- An SSH key pair on your device (`ssh-keygen -t ed25519` if you have none).
- Decisions 1 and 2 (provider and hardware, operating system and disk layout) from [choose-your-setup](../decide/choose-your-setup.md).
- Know how to reach the provider's rescue console.
- The public IP address your provider assigns, written `<public-ip>` below.

Commands assume an apt-based distribution (Ubuntu LTS is the worked example).

## Steps

### 1. Order with enough disk

Order more disk than you think you need; see [order enough disk up front](../learn/how-it-works.md#order-enough-disk-up-front). After install, confirm usable capacity with `df -h /`.

### 2. Install the OS with your key preinstalled

Use the provider's installer and paste your public key when it asks. Do not enable password login.

### 3. Create your user

Skip this if the provider created your user. Otherwise, on the box as root:

```bash
adduser <user>
usermod -aG sudo <user>
install -d -m 700 -o <user> -g <user> /home/<user>/.ssh
install -m 600 -o <user> -g <user> /root/.ssh/authorized_keys /home/<user>/.ssh/authorized_keys
```

The last line copies the key the installer placed for root; replace it with your own public key if the installer did not set one.

### 4. Install base packages

```bash
sudo apt-get update
sudo apt-get install -y build-essential git curl ca-certificates gnupg jq ripgrep fd-find unzip zstd htop ufw unattended-upgrades at bubblewrap gh shellcheck
```

`tmux` and `mosh` are not installed here; they belong to [do/08](08-optional-multiplexer.md).

### 5. Turn on security updates without surprise reboots

```bash
sudo dpkg-reconfigure -plow unattended-upgrades
grep -R "Automatic-Reboot" /etc/apt/apt.conf.d/
```

Keep `Unattended-Upgrade::Automatic-Reboot "false";` (set it in `/etc/apt/apt.conf.d/52-local-upgrades` if it is not already false). A reboot ends every live agent ([what nothing survives](../decide/access-modes.md#what-nothing-survives)), so reboot on your own schedule whenever `/var/run/reboot-required` exists.

### 6. Confirm logind keeps user processes after logout

Desktop-app daemons on the box outlive SSH disconnects only while `KillUserProcesses` is false ([access modes](../decide/access-modes.md#what-survives-a-disconnect)):

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager KillUserProcesses
```

Expected: `b false`. The stock `/etc/systemd/logind.conf` ships the option commented at that default. If it prints `b true`, set `KillUserProcesses=no` in `/etc/systemd/logind.conf` and run `sudo systemctl restart systemd-logind`.

## Check

From your device:

```bash
ssh <user>@<public-ip> true                                  # succeeds with your key
```

On the box:

```bash
df -h /                                                       # usable size matches what you ordered
test -f /var/run/reboot-required && echo pending || echo none # none after the first reboot
systemctl is-enabled unattended-upgrades                      # enabled
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager KillUserProcesses  # b false
```

## Needs a human

- Ordering the box and choosing disks.
- The provider's OS install screen or console.
- Storing the rescue console login in your password manager.
