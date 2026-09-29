# Lock down the network

After this page the box is reachable only from the mesh, SSH takes keys only, Docker publishes default to loopback, Funnel and Serve are off, and you have verified each of those from both sides. The reasoning is in the [security model](../learn/security-model.md).

## Goal

SSH and every service reachable only over the mesh; nothing listening for the public internet; checks prove it.

## Before you start

- [Provision the box](01-provision-the-host.md) is done, and the base packages include `at`.
- You know `<public-ip>` (`curl -4 ifconfig.me` on the box prints it).
- You can reach the provider's rescue console. Step 4 can lock you out if you get it wrong, and the console is the way back.
- Keep a second SSH session open for the whole page.

## Steps

### 1. Join the mesh

Install the mesh client from the vendor's instructions. Tailscale is the worked example; Headscale works with the same steps; NetBird and plain WireGuard need their own client and policy tools, and may need an inbound UDP port (see step 5). Tailscale install: <https://tailscale.com/kb/1031/install-linux>.

```bash
sudo tailscale up
```

This prints a login URL. Opening it and approving the device is a hand-off (see Needs a human). Then read the box's mesh address:

```bash
tailscale ip -4
```

Record the result as <mesh-ip> in your box notes. Add the box's mesh name or address to the SSH config on each device; [connect clients](05-connect-clients.md) shows how.

### 2. Write the mesh ACL

The ACL decides which peers reach which ports. Tag the box, then allow only your own devices to reach port 22 and the specific ports you need. Nothing else should be allowed to the box.

This is done in the mesh admin console or policy file, so it is a hand-off. Vendor docs: <https://tailscale.com/kb/1018/acls> (Tailscale); for other meshes, use the policy documentation of your mesh.

### 3. Harden sshd

Create the drop-in as a file, then validate it before reloading.

```bash
sudo tee /etc/ssh/sshd_config.d/60-hardening.conf >/dev/null <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
CONF
sudo sshd -t
sudo systemctl reload ssh
```

`sshd -t` prints nothing when the configuration is valid. Before you close any session, open a new terminal and log in with your key. If it fails, fix the drop-in from the session you kept open.

Make sure your public key is already in `~/.ssh/authorized_keys` before this step; with passwords off, it is the only way in.

### 4. Close public interfaces with a dead-man switch

Schedule a rollback first. If the firewall change locks you out, the box disables the firewall itself in ten minutes.

```bash
echo 'ufw disable' | sudo at now + 10 minutes
sudo atq
```

Note the job id from `atq`; you need it below. Then apply the firewall:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on <mesh-iface> to any port 22 proto tcp
sudo ufw --force enable
```

Replace <mesh-iface> with the mesh interface (`tailscale0` on Tailscale). If your mesh needs an inbound UDP port on the public interface (plain WireGuard's `ListenPort`), allow it before `ufw --force enable`. Tailscale does not need this: its `ts-input` chain accepts its UDP port before UFW. This closes the public interface only; peers on the mesh are governed by the mesh ACL.

Test from a second terminal on a mesh device that `ssh <box> true` still works, and from a device off the mesh that the public address no longer answers (Check below). When both pass, cancel only your own job:

```bash
sudo atrm <job-id>
```

Do not use `atrm $(atq ...)`: it removes every queued job on the box, not just this one. If you run mosh, its UDP rule is in [add a multiplexer](08-optional-multiplexer.md).

### 5. Keep Docker off public interfaces

Docker publishes bypass the host firewall ([why](../learn/security-model.md#docker-publishes-bypass-the-host-firewall)), so set the default bind to loopback before you run any container. This works before Docker is installed; [install toolchains](03-install-toolchains.md) installs it.

```bash
sudo mkdir -p /etc/docker
sudo cp examples/docker-daemon.json /etc/docker/daemon.json
```

Run that from the root of a clone of this repository, or copy the file's contents by hand. The file sets `ip` to `127.0.0.1` and rotates container logs. If Docker is already running, apply it:

```bash
sudo systemctl restart docker
```

In every compose file, write the host address in each `ports:` entry: `127.0.0.1:<port>:<port>`. An entry with no host address, or with `0.0.0.0`, follows or overrides the default and can publish on every interface.

To expose a port to mesh peers, bind it to the mesh address: `<mesh-ip>:<port>:<port>`. That address must exist when Docker starts, so order Docker after the mesh daemon with a drop-in:

```bash
sudo systemctl edit docker
```

Add these lines in the editor that opens, then save:

```ini
[Unit]
After=tailscaled.service
```

Record every mesh bind as an exception (format in the [security model](../learn/security-model.md#recording-an-exception)).

### 6. Turn off Funnel and Serve

```bash
tailscale serve status
tailscale funnel status
sudo tailscale funnel reset
sudo tailscale serve reset
```

Both `reset` subcommands are listed in `tailscale funnel --help` and `tailscale serve --help` (Observed, as of 2026-09). Anything you keep instead of resetting is an exception; record it.

## Check

Run every check. A single public-SSH probe does not find Docker publishes or Funnel.

1. sshd settings.

   ```bash
   sudo sshd -T | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
   ```

   Expected: `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin prohibit-password`. Some OpenSSH versions print `without-password` for the last one; it is the same setting.

2. Firewall.

   ```bash
   sudo ufw status verbose
   ```

   Expected: `Default: deny (incoming), allow (outgoing)` and an `ALLOW IN` rule for 22/tcp on <mesh-iface> only.

3. Listeners.

   ```bash
   sudo ss -tlnpuH
   ```

   Expected: listeners only on 127.0.0.1, ::1 and <mesh-ip>, plus sshd on 0.0.0.0:22 and [::]:22 (the firewall closes those to the public). UDP also shows the mesh daemon's WireGuard port on 0.0.0.0 and [::] (41641 on Tailscale, Observed as of 2026-09) and the DHCP client on port 68 of the public interface; both are expected. Investigate anything else. For TCP only, use `sudo ss -tlnpH`.

4. Docker publishes.

   ```bash
   docker ps --format '{{.Names}} {{.Ports}}' | grep -E '0\.0\.0\.0:|\[::\]:|:::'
   ```

   Expected: no output. Skip this check if Docker is not installed yet; repeat it after [install toolchains](03-install-toolchains.md).

5. Funnel and Serve.

   ```bash
   tailscale funnel status
   tailscale serve status
   ```

   Expected: both report nothing configured.

6. Off the mesh, from a device with the mesh turned off.

   ```bash
   nc -vz -w 5 <public-ip> 22
   ```

   Expected: the connection times out.

7. On the mesh.

   ```bash
   ssh <box> true; echo $?
   ```

   Expected: `0`.

8. Mesh tag applied (Tailscale).

   ```bash
   tailscale status --json | jq -r '.Self.Tags'
   ```

   Expected: the list includes the tag you chose in step 2. From a device your policy does not allow, `nc -vz -w 5 <mesh-ip> 22` times out (a hand-off below); without it, the ACL is unverified.

9. Rollback job gone.

   ```bash
   sudo atq
   ```

   Expected: no job for the `ufw disable` rollback.

10. Firewall ordering, for information only.

   ```bash
   sudo iptables -S INPUT | head -5
   ```

   On Tailscale, `-A INPUT -j ts-input` appears before the UFW chains, which is why the mesh ACL, not UFW, separates peers ([security model](../learn/security-model.md#on-tailscale-mesh-traffic-skips-ufw)).

## Needs a human

- Mesh login: the browser step of `sudo tailscale up`.
- Mesh ACL edit in the admin console or policy file, then the ACL probe: from a device the policy does not allow, `nc -vz -w 5 <mesh-ip> 22` must time out.
- The off-mesh probe: run it from a device with the mesh turned off, for example a phone on cellular data.
- The provider's rescue console, if you are locked out.
