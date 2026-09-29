# Choose your setup

You make eight decisions to build a box. Each has a default below; if you are unsure, take the default and move on. Write your answers in your [box notes](../do/00-bootstrap-with-an-agent.md#3-create-the-box-notes) so your coding agent can build from them. Vendor claims carry a [status label](../../README.md#status-labels), as of 2026-09.

## 1. Provider and hardware

**Default:** a dedicated server or a large cloud VM with an x86-64 or Arm CPU, 8 or more cores, and 32 GB or more RAM.

- **Dedicated server:** fixed monthly price, no noisy neighbors, good for many parallel agents and long builds. Storage is fixed when you order.
- **Cloud VM:** hourly billing and resizable disks, at a higher price for the same cores. Good if you want to start small.

Size for the heaviest thing you run in parallel: each agent session plus its builds, test containers and language servers. Size disk up front; see [order enough disk up front](../learn/how-it-works.md#order-enough-disk-up-front).

## 2. Operating system and disk layout

**Default:** a current Ubuntu LTS release with a single mirrored root volume.

The guides use an apt-based distribution as the worked example. Any Linux with systemd works, but commands differ. A separate data volume is worth it only when you have a reason, such as keeping Docker images and build caches apart from the root volume or resizing them independently.

## 3. Mesh

**Default:** Tailscale.

Alternatives: Headscale (self-hosted Tailscale control server), NetBird, or plain WireGuard.

The box reaches your devices through the mesh, and SSH stays closed on public interfaces. Whichever you choose, its access policy (the mesh ACL) must express one rule: only your own devices reach the box's SSH port and the ports you deliberately open. That policy, not the host firewall, is the peer boundary. See the [security model](../learn/security-model.md).

## 4. Devices and clients

**Default:** each harness's desktop app over SSH, an editor over SSH, and the CLI over SSH.

- Desktop app over SSH: the Claude desktop app's Code tab with an SSH environment, and the Codex app's Remote SSH connection.
- Editor over SSH: Cursor, VS Code or Zed Remote-SSH, for reading and editing.
- CLI over SSH: everything else, from any terminal.

Which client runs on which OS is in [client OS support](access-modes.md#client-os-support). To wire them up, follow [connect your clients](../do/05-connect-clients.md).

## 5. Multiplexer

**Default:** none.

The desktop apps keep their own long-lived processes on the box ([access modes](access-modes.md#what-survives-a-disconnect)), so a multiplexer adds little for them. Add tmux or Herdr only if you run terminal agents that you want to reattach from any SSH client, or you want to SSH from a phone into live sessions. When that is worth it, and how to set each up, is in [add a multiplexer](../do/08-optional-multiplexer.md).

**Orchestration default:** one lead agent supervising the native CLIs inside Herdr, not a unifying harness or a custom controller, so every harness keeps its own subscription login. Run several agents only when the work splits into independent pieces. The reasons and the operating model are in [coordinate several agents](coordinate-agents.md); the recipes are in [coordinate agents with Herdr](../do/09-coordinate-agents-with-herdr.md).

## 6. Harnesses and billing

You pay for a harness in one of two ways: a subscription login (a plan account) or an API key (per-token billing, including gateways).

### Subscription login

Sign in with a plan account instead of a key.

- Claude Code and the Claude desktop app: a Claude Pro, Max, Team or Enterprise account.
- Codex and the Codex app: a ChatGPT plan.
- Cursor: a Cursor plan.

Anthropic states that subscription OAuth is intended for purchasers of Claude Free, Pro, Max, Team and Enterprise using Claude Code and other native Anthropic apps, and that third parties may not route requests through Free, Pro or Max credentials. Your own API key in your own development environment is allowed (Documented: [Claude Code legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)).

### API keys and gateways

Prefer an API key when you need a harness that has no subscription path, want one bill across providers, run automation that should not consume a personal plan, or route through a gateway. Cost scales with tokens, so heavy agent use can cost more than a flat plan. Keep keys in environment variables or a secret manager, never in a file you commit.

### OpenCode cannot use a Claude subscription

OpenCode's providers page says Anthropic prohibits plugins that use Claude Pro or Max login, that such plugins stopped being bundled as of OpenCode 1.3.0, and that API key auth is the Anthropic path (Documented: [OpenCode providers](https://opencode.ai/docs/providers/)). OpenCode fits readers who use API keys or several providers: it supports 75+ providers plus local models.

Whether OpenAI sanctions ChatGPT-plan login in third-party tools such as OpenCode is Unverified: no primary OpenAI source confirms it. See OpenAI's [Codex with your ChatGPT plan](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan) for what is documented.

Which login each client bills (the device's or the box's) is in [where billing comes from](access-modes.md#where-billing-comes-from).

## 7. Approvals

**Default:** approvals on, in every harness.

Running with approvals off is a trade-off you record as an exception, not a default. The trade-off and the compensating controls are in the [security model](../learn/security-model.md#harness-approvals).

## 8. Backup target

**Default:** an offsite, encrypted repository in an account other than the box provider's, if you can.

A backup that shares an account with the box fails with the account. Scope and setup are in [back up the box](../do/07-back-up.md).
