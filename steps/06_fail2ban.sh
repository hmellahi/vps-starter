#!/usr/bin/env bash
# ─── Step 06: Fail2Ban ──────────────────────────────────────
# Sub-steps: install | write_jail | start | verify
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" sudo "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

install() {
  ssh_sudo apt-get install -y -qq fail2ban
}

write_jail() {
  local bantime findtime maxretry
  bantime=$(get_env "FAIL2BAN_BANTIME")
  findtime=$(get_env "FAIL2BAN_FINDTIME")
  maxretry=$(get_env "FAIL2BAN_MAXRETRY")

  ssh_sudo bash -c "cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = ${bantime}
findtime = ${findtime}
maxretry = ${maxretry}
backend  = auto

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = ${maxretry}
EOF"
}

start() {
  ssh_sudo systemctl enable fail2ban
  ssh_sudo systemctl start fail2ban
}

verify() {
  ssh_sudo fail2ban-client status sshd
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  install)    install    ;;
  write_jail) write_jail ;;
  start)      start      ;;
  verify)     verify     ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
