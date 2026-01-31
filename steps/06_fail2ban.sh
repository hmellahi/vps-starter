#!/usr/bin/env bash
# ─── Step 06: Fail2Ban ──────────────────────────────────────
# Sub-steps: install | write_jail | start | verify
# ────────────────────────────────────────────────────────────
set -euo pipefail

CFG="$(dirname "$0")/../config.yml"
VPS_IP=$(grep -m1 "^vps_ip:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
KEY_PATH=$(grep -m1 "^ssh_key_path:" "$CFG" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" sudo "$@"
}

yaml_val() {
  grep -m1 "^${1}:" "$CFG" | sed 's/^[^:]*: *//;s/"//g'
}

# ─── sub-steps ──────────────────────────────────────────────

install() {
  ssh_sudo apt-get install -y -qq fail2ban
}

write_jail() {
  local bantime findtime maxretry
  bantime=$(yaml_val fail2ban_bantime)
  findtime=$(yaml_val fail2ban_findtime)
  maxretry=$(yaml_val fail2ban_maxretry)

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
