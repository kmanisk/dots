# ChatGPT Local Coder & Tailscale Funnel Architecture and Setup Workflow

Target machine: ASUS TUF Gaming F16 (FX608JH) · CachyOS Linux · Sway (Wayland)

---

## 1. Overview & Architecture

ChatGPT Local Coder provides a self-hosted, open-source Model Context Protocol (MCP) HTTP bridge connecting ChatGPT Web and local Codex clients directly to the Linux workstation over Tailscale Funnel. The production service runs under an independently restricted system account (`localcoder`, UID 947, GID 947) with an ed25519-signed Policy Gateway at `/opt/local-coder-policygate`.

```text
 ChatGPT Web / Codex Client
       │
       ▼ (Public HTTPS with MagicDNS / Let's Encrypt certificates)
 Tailscale Funnel Ingress (:443)
       │
       ▼ (Forwarded loopback traffic over WireGuard tunnel)
 Local Policy Gateway (127.0.0.1:3000) [User: localcoder, UID 947]
       │
       ├── Endpoints : /<MCP_TOKEN> and /mcp/<MCP_TOKEN>
       ├── Sandbox   : ProtectHome=yes, ProtectSystem=strict
       ├── Context   : /srv/local-coder/context/chezmoi (Read-only bind)
       ├── Workspace : /srv/local-coder/workspace and /srv/local-coder/projects (BindPaths)
       ├── Ledger    : /var/log/local-coder-policygate/audit.jsonl (mode 0660, chattr +a)
       └── Escalation: /usr/local/bin/local-coder-escalation-broker (narrow root broker)

 Localhost-Only Admin UI (127.0.0.1:3001/ui)
       ├── Bound strictly to loopback (localhostOnly middleware)
       └── Protected by ADMIN_TOKEN and loopback address enforcement
```

Production deployment path: `/opt/local-coder-policygate`  
Production systemd unit: `/etc/systemd/system/chatgpt-local-coder-policygate.service`  
Configuration root: `/etc/local-coder-policygate/`  
Legacy fallback checkout: `/home/onyx/Projects/chatgpt-local-coder` (retained for rollback)

---

## 2. Machine Prerequisites

1. **System Packages:**
   - `tailscale` (provides `tailscaled` daemon and CLI tool).
   - `pnpm` (fast, reproducible node package manager honoring `pnpm-lock.yaml`).
   - `age` (modern encryption tool used for securing connector secrets).
   - `jq` (JSON query tool for health and telemetry parsing).
   - Package manifests tracked under `packages/common.txt` and `packages/development.txt`.

2. **Snapper Snapshot Safety Baseline:**
   - Any system package installation must be preceded by a pre-installation snapshot:
     ```bash
     sudo snapper -c root create -d "pre-install tailscale pnpm for local-coder" -t pre
     ```
   - Package transactions automatically trigger post-installation snapshots via pacman hooks.

---

## 3. Step-by-Step Installation & Build

### Step 3.1: Clone and Pin Upstream Repository
Clone the repository into the dedicated project workspace:
```bash
git clone https://github.com/hoangcoderr/chatgpt-local-coder.git /home/onyx/Projects/chatgpt-local-coder
cd /home/onyx/Projects/chatgpt-local-coder
git checkout bc2ce5e6cb12fac20633065fb122fabbbb5c98c3
```

### Step 3.2: Install Dependencies with Frozen Lockfile
Install project dependencies using the upstream lockfile to guarantee exact reproducibility:
```bash
pnpm install --frozen-lockfile
```

### Step 3.3: TypeScript Build
Compile TypeScript source files into executable ES modules in `dist/`:
```bash
pnpm run build
```

### Step 3.4: Comprehensive Test Suite Execution
Run the full unit and integration test suites before enabling the service:
```bash
pnpm run test:all
```
This validates all 43 tests across:
- Patch application and unified diff parsing (`test-patch.mjs`).
- Tool execution, regex substitution, glob, and grep (`test-tools.mjs`).
- Checkpoint creation and rewind capabilities (`test-checkpoints.mjs`).
- Upstream configuration parsing and stdio bridges (`test-mcp-upstream.mjs`).
- OAuth client credential handling (`test-mcp-oauth.mjs`).
- Structured audit logging (`test-activity-log.mjs`).
- Project memory injection and prompt sizing (`test-project-memory.mjs`).
- Slim profile filtering (`test-tool-profile.mjs`).
- Shell session persistence (`test-shell-persist.mjs`).
- Streamable HTTP transport initialization and recovery (`test-mcp-session.mjs`).

---

## 4. Configuration & Security Model

The production server configuration resides in `/etc/local-coder-policygate/service.env` with owner-only permissions (`mode 0600`, owned by `root:root`).

### Production Configuration Parameters
```dotenv
HOST=127.0.0.1
PORT=3000
ADMIN_PORT=3001
MCP_TOKEN=<CRYPTOGRAPHICALLY_RANDOM_256_BIT_TOKEN>
ADMIN_TOKEN=<CRYPTOGRAPHICALLY_RANDOM_256_BIT_TOKEN>
POLICYGATE_POLICY_FILE=/etc/local-coder-policygate/policy.json
POLICYGATE_APPROVAL_PUBLIC_KEY=/etc/local-coder-policygate/operator-public.pem
POLICYGATE_OPERATOR_PRIVATE_KEY=/etc/local-coder-policygate/operator-private.pem
POLICYGATE_APPROVAL_DIR=/var/lib/local-coder-policygate/approvals
POLICYGATE_AUDIT_ANCHOR_FILE=/etc/local-coder-policygate/audit-anchor.json
POLICYGATE_ENV_FILE=/etc/local-coder-policygate/service.env
LOCAL_CODER_CHEZMOI_SOURCE_DIR=/srv/local-coder/context/chezmoi
MCP_UPSTREAM_CONFIG=/etc/local-coder-policygate/mcp-upstream.json
POST_EDIT_HOOKS_CONFIG=/etc/local-coder-policygate/post-edit-hooks.json
HOME=/var/lib/local-coder-policygate/home
MCP_SHELL_STATE_DIR=/var/lib/local-coder-policygate/home/.mcp-state
MCP_OAUTH_STORE=/var/lib/local-coder-policygate/home/.mcp-oauth
WORKSPACE_PATH=/srv/local-coder/workspace
CHATGPT_TOOL_PROFILE=slim
PATH=/opt/local-coder-policygate/bin:/usr/local/bin:/usr/bin:/bin
```

### Three Operational Security Modes
1. **Mode 1 — STRICT:**
   - Read-only inspection by default.
   - Sudo is strictly forbidden (`POLICYGATE_STRICT_NO_SUDO`).
   - Mutations (`W` and `X` class tools) require explicit signed operator approval.
   - Only basic diagnostic commands (`pwd`, `id`, `whoami`) execute without approval.
   - Switch via: `sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs mode strict`.

2. **Mode 2 — STANDARD (Default):**
   - Everyday ChatGPT, Codex, and development workflow profile.
   - Reads and edits inside explicitly approved project roots (`/srv/local-coder/workspace`, `/srv/local-coder/projects`) execute without approval.
   - Ordinary build, test, and diagnostic commands execute without approval.
   - Safe read-only Git tools (`git_status`, `git_diff`, `git_log`, `git_branch`) execute without approval.
   - Privileged operations (`sudo`, `pacman`, `systemctl`), destructive actions (`rm -rf /`, `mkfs`), and remote pushes require out-of-band signed operator approval.
   - Switch via: `sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs mode standard`.

3. **Mode 3 — YOLO / FULL ACCESS:**
   - High-risk full-machine mode for emergency system administration.
   - Activated only through root operator action on an interactive TTY via `sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs yolo --duration <minutes>`.
   - Generates a root-signed ed25519 lease `/var/lib/local-coder-policygate/yolo-lease.json`.
   - While the lease is active, commands bypass discretionary approval checks.
   - Privileged escalation executes through a narrow root broker `/usr/local/bin/local-coder-escalation-broker` allowlisted in `/etc/sudoers.d/local-coder-policygate` (`localcoder ALL=(root) NOPASSWD: /usr/local/bin/local-coder-escalation-broker *`).
   - Automatically reverts to STANDARD mode upon lease expiry, service restart, or explicit exit (`policygate-operator.mjs yolo --off`).
   - Does not grant `localcoder` general passwordless sudo.

### Security Invariants & Rationale
1. **Path-Based MCP Token Authentication:**
   - The MCP endpoint is routed at `/<MCP_TOKEN>` and `/mcp/<MCP_TOKEN>`.
   - Any request lacking the token returns HTTP 404 (Not Found).
   - Reuses preserved production token so existing ChatGPT connector pairings remain valid.

2. **Loopback-Only Admin GUI & API:**
   - The admin interface listens on `127.0.0.1:3001` and requires `ADMIN_TOKEN`.
   - The `localhostOnly` middleware rejects non-loopback requests with HTTP 403.
   - Tailscale Funnel is strictly restricted to port 3000; port 3001 is never forwarded.

3. **Append-Only Hash-Chained Audit Ledger:**
   - Located at `/var/log/local-coder-policygate/audit.jsonl`.
   - Owned by `root:localcoder` with mode `0660` inside a `0750` directory.
   - Protected by the Linux filesystem append-only attribute (`chattr +a`).
   - Each entry contains a SHA-256 hash linking back to the previous entry, anchored to `/etc/local-coder-policygate/audit-anchor.json`.

4. **Tested Rollback Runbook:**
   - Stopping `chatgpt-local-coder-policygate.service` and starting user service `chatgpt-local-coder.service` restores the legacy user-mode implementation in 1.1 seconds.

---

## 5. Secret Management & Age Encryption

To prevent credential leaks, connector details are kept out of project directories and user workspaces.

### Encrypted Vault Storage
- Directory: `~/.local/share/chatgpt-local-coder/` (mode `0700`, owner-only).
- Secret Identity Key: `~/.local/share/chatgpt-local-coder/key.txt` (mode `0600`).
- Encrypted Payload: `~/.local/share/chatgpt-local-coder/connector.age` (mode `0600`).

### On-Demand Decryption Utility
The `local-coder-url` helper decrypts the connector URL on-the-fly directly in the terminal without writing plaintext to disk:
```bash
# Print connector URL for clipboard / copy:
local-coder-url

# Print full connection parameters:
local-coder-url --all

# Pipe URL directly into system clipboard:
local-coder-url | wl-copy
```

---

## 6. Tailscale & Funnel Gateway Setup

Tailscale Funnel routes public HTTPS requests from the Internet through Tailscale's global edge infrastructure to the local `tailscaled` daemon, which proxies to loopback port 3000.

### Step 6.1: Tailscale Node Authentication
Start the daemon and authenticate with non-root operator delegation:
```bash
sudo systemctl start tailscaled.service
sudo tailscale up --operator=onyx
```
This prints a one-time browser login URL. Once approved, the laptop joins the user's Tailnet as an active node.

### Step 6.2: Enable Funnel in Tailnet ACL
When enabling Funnel for the first time, visit the Tailscale admin console prompt:
```text
https://login.tailscale.com/f/funnel?node=<NODE_ID>
```
Approve the Funnel capability for the device.

### Step 6.3: Activate Background Ingress
Forward public HTTPS traffic to the local MCP server:
```bash
tailscale funnel --bg 3000
```
Verify the active configuration:
```bash
tailscale funnel status
```
Output confirms:
```text
https://<device>.<tailnet>.ts.net (Funnel on)
|-- / proxy http://127.0.0.1:3000
```

### DNS and Hairpinning Note
On the public Internet, `https://<device>.<tailnet>.ts.net` resolves to Tailscale edge ingress IPs (e.g., Let's Encrypt HTTPS proxies). Within the local workstation, MagicDNS resolves the hostname directly to the node's WireGuard IP. Testing the public Funnel endpoint from the host itself requires routing through the public ingress IP (`curl --resolve ...`) or connecting from an external network.

---

## 7. ChatGPT Web Integration Workflow

### Adding the Custom MCP Server
1. In your browser, navigate to:
   ```text
   https://chatgpt.com/plugins
   ```
   (or click **Settings → Apps → Connectors → Add custom MCP server**).

2. Enter the connection settings:
   - **Name:** `Local Coder`
   - **Description:** `Access my Linux files, Git repositories, and terminal commands.`
   - **Connection:** Select **`Server URL`**
   - **Server URL:** Paste the complete URL generated by `local-coder-url`:
     ```text
     https://<device>.<tailnet>.ts.net/mcp/[REDACTED_MCP_TOKEN]
     ```
   - **Authentication:** Select **`None`** (Critical: do not leave on `OAuth`).

3. Check **`I understand and want to continue`** and click **`Create as a plugin`**.

4. Confirm the connection prompt.

### Permission Configuration
In **Settings → Apps → Connectors → Local Coder**, configure permissions:
- Set to **"Ask before major changes"** or **"Ask before changes"**.
- Do not click "Always allow" on individual tool popups during chat sessions, as this can trigger a known ChatGPT UI bug that prematurely aborts long SSE streaming connections.

---

## 8. Daemonless Operational Lifecycle

In strict adherence to the workstation's daemonless residency policy, development servers do not run persistent background daemons at boot. Both `chatgpt-local-coder.service` and `tailscaled.service` remain disabled at boot and are orchestrated on-demand.

### Operational CLI Tools
All commands are located in `~/.local/bin/` and tracked in chezmoi:

- **`local-coder-switch`:**
  - One-command switcher between secured Policy Gateway and legacy Local Coder:
    - `local-coder-switch new`: Stops legacy user service, starts Policy Gateway system service, verifies HTTP 200 health on port 3000, and automatically rolls back if health verification fails.
    - `local-coder-switch legacy`: Stops Policy Gateway system service, restores legacy user service, verifies health, and rolls back if health verification fails.
    - `local-coder-switch status`: Displays active version, main PID, execution UID, active security mode, local port, public endpoint, and health status.

- **`policygate-operator`:**
  - Dedicated operator security mode, lease, and approval CLI:
    - `policygate-operator mode strict`: Enforces read-only profile; mutations require signed approvals; sudo blocked.
    - `policygate-operator mode standard`: Sets default development mode with scoped workspace mutations and signed sudo approvals.
    - `policygate-operator yolo --duration <minutes>`: Prompts interactive confirmation and issues a cryptographically signed Ed25519 temporary lease for full machine administration.
    - `policygate-operator yolo --off`: Deactivates YOLO lease immediately and returns to standard mode.
    - `policygate-operator status`: Reports current security mode and lease status.

- **`policygate-project`:**
  - Scoped workspace mapper for host projects under UID 947 with `ProtectHome=yes`:
    - `policygate-project map <project>`: Configures POSIX ACLs (`u:localcoder:rwx`, `u:onyx:rwx`, and default ACLs) on host directory and bind-mounts it into `/srv/local-coder/projects/<project>`.
    - `policygate-project unmap <project>`: Unmounts and cleans up mount directory.
    - `policygate-project list`: Lists all active project mappings.

- **`local-coder-start`:**
  - Validates ports 3000 and 3001 are free of conflicting processes.
  - Starts `tailscaled.service` (if not running).
  - Verifies Tailscale authentication state.
  - Starts user service `chatgpt-local-coder.service`.
  - Polls `http://127.0.0.1:3000/health` until 200 OK.
  - Ensures Tailscale Funnel is forwarding port 3000.
  - Invokes `local-coder-status`.

- **`local-coder-status`:**
  - Reports systemd service status, main PID, and memory footprint.
  - Probes local health endpoint and reports tool profile and active sessions.
  - Reports Tailscale core connection status and current Funnel mapping.
  - Displays recent service journal lines.

- **`local-coder-stop`:**
  - Resets Tailscale Funnel forwarding (`tailscale funnel reset`).
  - Stops `chatgpt-local-coder.service`.
  - Stops `tailscaled.service` to eliminate idle memory and wakeup overhead.
  - Confirms ports 3000 and 3001 are fully released.

- **`local-coder`:**
  - Unified CLI dispatcher supporting: `start`, `status`, `stop`, `restart`, `logs`.

### Systemd Production Policy Gateway Service Definition
File: `/etc/systemd/system/chatgpt-local-coder-policygate.service`
```ini
[Unit]
Description=ChatGPT Local Coder Policy Gateway (Production)
After=network.target

[Service]
Type=simple
User=localcoder
Group=localcoder
UMask=0077
EnvironmentFile=/etc/local-coder-policygate/service.env
WorkingDirectory=/srv/local-coder/workspace

# Read-only snapshot of canonical chezmoi docs
BindReadOnlyPaths=/home/onyx/.local/share/chezmoi:/srv/local-coder/context/chezmoi

# Writable sandbox paths
BindPaths=/srv/local-coder/workspace
BindPaths=/srv/local-coder/projects
BindPaths=/var/lib/local-coder-policygate
BindPaths=/var/log/local-coder-policygate

# OS Sandboxing
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=no
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictRealtime=yes
MemoryDenyWriteExecute=no

ExecStartPre=/usr/bin/node /opt/local-coder-policygate/scripts/production-preflight.mjs
ExecStart=/usr/bin/node /opt/local-coder-policygate/dist/index.js
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
```

### Sway Desktop Scratchpad Integration
The workstation's global keyboard shortcut **`Win + Alt + D`** (`$mod+Mod1+d`) is configured in `dot_config/sway/config.d/40-keybindings.conf` and `dot_local/bin/executable_scratch-toggle` to toggle the live Local Coder monitor:
- Spawns `local-coder-monitor` in a floating centered terminal (`1500x950`) with tuned font (`size=15` pt via `SCRATCH_DC_FONT_SIZE`).
- Renders high-contrast ANSI color-coded service telemetry, current security mode indicator, memory footprint, and Tailscale Funnel mapping.
- Continuously streams structured tool calls from `/var/log/local-coder-policygate/audit.jsonl` (with fallback to legacy audit log) with vibrant category colors and local 12-hour AM/PM timestamps (`%I:%M:%S %p`).
- Pressing `Win + Alt + D` slides the scratchpad down; pressing it again dismisses it.

---

## 9. Verification & Troubleshooting Runbook

### Operational Commands
```bash
# 1. Check live status and active security mode
local-coder-status

# 2. Inspect active audit ledger
sudo tail -f /var/log/local-coder-policygate/audit.jsonl

# 3. Switch security mode
sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs mode strict
sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs mode standard

# 4. Activate temporary YOLO mode (30 minutes)
sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs yolo --duration 30

# 5. Deactivate YOLO mode immediately
sudo /usr/bin/node /opt/local-coder-policygate/scripts/policygate-operator.mjs yolo --off

# 6. Verify audit chain integrity
sudo node --input-type=module -e '
import { verifyAuditFile } from "/opt/local-coder-policygate/dist/lib/hash-audit.js";
console.log(verifyAuditFile("/var/log/local-coder-policygate/audit.jsonl"));
'

# 7. Instant Rollback to Legacy User Service (< 2 seconds)
sudo systemctl stop chatgpt-local-coder-policygate.service
systemctl --user start chatgpt-local-coder.service
```

# 3. Verify unauthenticated requests are rejected with 404
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/mcp

# 4. Stream audit logs of ChatGPT tool calls
tail -f /home/onyx/Projects/chatgpt-local-coder/.mcp-audit.log

# 5. Verify system residency policy compliance
system-residency-audit
```

### Common Issues & Solutions

1. **ChatGPT displays "Could not connect to server" during setup:**
   - Verify `local-coder-status` shows Funnel is active.
   - Verify the URL contains the exact path token `/mcp/<TOKEN>`.
   - Ensure `Authentication` is set to `None` in the ChatGPT dialog.

2. **Admin UI displays `{"ok":false,"error":"Invalid admin token"}`:**
   - Verify `ADMIN_TOKEN=` is left empty in `/home/onyx/Projects/chatgpt-local-coder/.env`. Setting an admin token forces HTTP Bearer headers which standard web browsers cannot send during regular navigation.

3. **ChatGPT tool calls time out:**
   - Open the live monitor (`Win + Alt + D`) to check if a synchronous command is exceeding `SHELL_TIMEOUT=120`. For long jobs, instruct ChatGPT to use `start_process` instead of `run_command`.
