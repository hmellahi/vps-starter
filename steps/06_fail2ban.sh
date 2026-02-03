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
  # Check if fail2ban is already installed
  local f2b_installed=$(ssh_sudo "command -v fail2ban-client >/dev/null 2>&1 && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$f2b_installed" == "EXISTS" ]]; then
    echo "Fail2Ban already installed — skipping"
    return 0
  fi
  
  ssh_sudo apt-get install -y -qq fail2ban
}

write_jail() {
  # Check if jail.local already exists
  local jail_exists=$(ssh_sudo "test -f /etc/fail2ban/jail.local && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$jail_exists" == "EXISTS" ]]; then
    echo "Fail2Ban jail.local already configured — skipping"
    return 0
  fi
  
  # Use defaults if not in .env (get_env can fail if var missing)
  local bantime findtime maxretry
  bantime=$(get_env "FAIL2BAN_BANTIME" 2>/dev/null) || true
  findtime=$(get_env "FAIL2BAN_FINDTIME" 2>/dev/null) || true
  maxretry=$(get_env "FAIL2BAN_MAXRETRY" 2>/dev/null) || true
  bantime=${bantime:-3600}
  findtime=${findtime:-600}
  maxretry=${maxretry:-5}

  # Build content and write via single sudo call (avoids heredoc/quoting over SSH)
  local jail_content="[DEFAULT]
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
"
  echo "$jail_content" | ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "sudo tee /etc/fail2ban/jail.local > /dev/null"
}

start() {
  # Check if fail2ban is already active
  local f2b_active=$(ssh_sudo systemctl is-active fail2ban 2>/dev/null || echo "inactive")
  
  if [[ "$f2b_active" == "active" ]]; then
    echo "Fail2Ban already running — skipping"
    return 0
  fi
  
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
