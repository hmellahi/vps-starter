# [DRAFT] VPS Deploy

Automates VPS provisioning, hardening, and Docker app deployment.

**JS orchestrator + bash step files.** The JS layer handles config, live UI (spinners, status board), and error logging. The bash files are pure command runners — one file per step, trivial to read and edit.

---

## Quick Start

# Run setup (Steps 2 → 13)

npm run setup

# --- Backup (run anytime, completely independent) ---

npm run backup

```

---

## Folder Layout

```

vps-deploy/
├── package.json
├── .env.example ← template for configuration
├── .env ← your actual config (gitignored)
├── setup.js ← setup orchestrator (Steps 2–13)
├── backup.js ← backup orchestrator
├── src/ ← JS internals
│ ├── config.js ← .env loader + validation
│ ├── logger.js ← writes deploy.log + errors.txt
│ ├── ui.js ← terminal rendering (spinners, boxes, summary)
│ ├── ssh.js ← sshRoot / sshDeploy / sshSudo / scpPull
│ └── runner.js ← runStep() / runSection() core loop
├── steps/ ← pure bash, one file per step
│ ├── 02_initial_setup.sh
│ ├── 03_ssh_keys.sh
│ ├── 04_firewall.sh
│ ├── 05_harden_ssh.sh
│ ├── 06_fail2ban.sh
│ ├── 07_auto_updates.sh
│ ├── 08_docker.sh
│ ├── 12_deploy_code.sh
│ └── 13_docker_compose.sh
├── backups/ ← created by backup.js
│ └── 2025-01-31T14-30-22/ ← timestamped snapshots
├── deploy.log ← full run log (runtime)
└── errors.txt ← only failed steps (runtime)

```

---

## How It Works

```

setup.js ← defines WHAT runs and in what order
└── runner.js (runSection) ← iterates steps, shows spinner per step
└── bash steps/\*.sh ← does the actual remote work
└── ssh / sshpass ← talks to the VPS

````

Each bash step file dispatches on `$1`:

```bash
# The JS runner calls:
bash steps/04_firewall.sh "allow_core"

# The file does:
case "$1" in
  allow_core) ...commands... ;;
esac
````

This means you can also run any single sub-step manually from your terminal for debugging:

```bash
bash steps/04_firewall.sh verify
```

---

## What Gets Skipped (By Design)

| Skipped                      | Why                             |
| ---------------------------- | ------------------------------- |
| Step 1 (Provision VPS)       | Done manually on your provider  |
| Step 10 (Restore backup)     | Use `npm run backup` separately |
| Step 11 (Credentials / .env) | Secrets are never automated     |
| Steps 14–21 (SSL, DNS, CI)   | Do these after setup completes  |
| All testing steps            | Verify manually                 |

---

## .env Reference

| Key                 | Description                                                   |
| ------------------- | ------------------------------------------------------------- |
| `VPS_IP`            | IP address of your VPS                                        |
| `ROOT_PASSWORD`     | Root password (Option 1: password auth - requires `sshpass`)  |
| `SSH_KEY_PATH`      | Path to root SSH key (Option 2: key auth - **recommended**)   |
| `SSH_KEY_PATH`      | Local path for the ED25519 key pair (`$HOME` is expanded)     |
| `GITHUB_REPO`       | Full HTTPS URL to your GitHub repo                            |
| `GITHUB_TOKEN`      | GitHub personal access token for private repos (optional)     |
| `APP_DIR_NAME`      | Folder name after `git clone`                                 |
| `APP_PORT`          | Port your app exposes (reference only)                        |
| `EXTRA_PORTS`       | Comma-separated additional firewall ports (e.g., `8080,5432`) |
| `FAIL2BAN_BANTIME`  | Ban duration in seconds                                       |
| `FAIL2BAN_FINDTIME` | Window to count failures (seconds)                            |
| `FAIL2BAN_MAXRETRY` | Attempts before ban                                           |

**Authentication:** You must provide **either** `ROOT_PASSWORD` **or** `SSH_KEY_PATH` (not both).

---

## Prerequisites

- Node.js 18+
- `ssh` / `ssh-keygen` / `scp`
- `sshpass` — only needed if using password authentication (`brew install sshpass` or `apt install sshpass`)
  - Not required if using SSH key authentication (recommended)

---

## Troubleshooting

- **errors.txt** — only lines for steps that actually failed.
- **deploy.log** — full timestamped output of every command.
- Run any sub-step manually: `bash steps/<file>.sh <sub-step-name>`

# vps-starter
