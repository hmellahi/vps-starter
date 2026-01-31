#!/usr/bin/env bash
# ─── Step 05: Harden SSH ────────────────────────────────────
# Sub-steps: patch_config | validate | restart
# ────────────────────────────────────────────────────────────
set -euo pipefail

CFG="$(dirname "$0")/../config.yml"
VPS_IP=$(grep -m1 "^vps_ip:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
KEY_PATH=$(grep -m1 "^ssh_key_path:" "$CFG" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" sudo "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

patch_config() {
  ssh_sudo bash -c '
    CONF=/etc/ssh/sshd_config
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin no/"              "$CONF"
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$CONF"
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/"   "$CONF"
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries 3/"                    "$CONF"
    sed -i "/^AllowUsers/d"                                          "$CONF"
    echo "AllowUsers deployer" >> "$CONF"
  '
}

validate() {
  ssh_sudo sshd -t
}

restart() {
  ssh_sudo systemctl restart sshd
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  patch_config) patch_config ;;
  validate)     validate     ;;
  restart)      restart      ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
