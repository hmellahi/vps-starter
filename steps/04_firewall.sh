#!/usr/bin/env bash
# ─── Step 04: Firewall (UFW) ────────────────────────────────
# Sub-steps: set_defaults | allow_core | allow_extra | enable | verify
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

set_defaults() {
  ssh_sudo ufw default deny incoming
  ssh_sudo ufw default allow outgoing
}

allow_core() {
  ssh_sudo ufw allow 22/tcp
  ssh_sudo ufw allow 80/tcp
  ssh_sudo ufw allow 443/tcp
}

allow_extra() {
  # Pull extra_ports list out of the YAML (handles both inline [] and block list)
  local ports
  ports=$(sed -n '/^extra_ports:/,/^[^ ]/p' "$CFG" | grep '^\s*-' | sed 's/.*- *//')

  if [[ -z "$ports" ]]; then
    echo "No extra ports configured"
    exit 0
  fi

  for port in $ports; do
    ssh_sudo ufw allow "${port}/tcp"
    echo "Allowed port $port"
  done
}

enable() {
  ssh_sudo bash -c 'echo "y" | ufw enable'
}

verify() {
  ssh_sudo ufw status
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  set_defaults) set_defaults ;;
  allow_core)   allow_core   ;;
  allow_extra)  allow_extra  ;;
  enable)       enable       ;;
  verify)       verify       ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
