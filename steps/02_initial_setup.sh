#!/usr/bin/env bash
# ─── Step 02: Initial Server Setup ─────────────────────────
# Sub-steps: update_system | create_deployer | add_sudo
# Called by the JS runner as: bash 02_initial_setup.sh <sub-step>
# ────────────────────────────────────────────────────────────
set -euo pipefail

VPS_IP=$(grep -m1 "^vps_ip:" "$(dirname "$0")/../config.yml" | sed 's/^[^:]*: *//;s/"//g')
ROOT_PASS=$(grep -m1 "^root_password:" "$(dirname "$0")/../config.yml" | sed 's/^[^:]*: *//;s/"//g')

ssh_root() {
  sshpass -p"$ROOT_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

update_system() {
  ssh_root "apt-get update -qq && apt-get upgrade -y -qq"
}

create_deployer() {
  local pass
  pass=$(grep -m1 "^deployer_password:" "$(dirname "$0")/../config.yml" | sed 's/^[^:]*: *//;s/"//g')
  ssh_root "useradd -m -s /bin/bash deployer || true && echo 'deployer:${pass}' | chpasswd"
}

add_sudo() {
  ssh_root "usermod -aG sudo deployer"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  update_system)   update_system   ;;
  create_deployer) create_deployer ;;
  add_sudo)        add_sudo        ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
