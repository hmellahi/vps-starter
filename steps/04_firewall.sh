#!/usr/bin/env bash
# ─── Step 04: Firewall (UFW) ────────────────────────────────
# Sub-steps: set_defaults | allow_core | allow_extra | enable | verify
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
  # Get extra ports from .env (comma-separated)
  local extra_ports
  extra_ports=$(get_env "EXTRA_PORTS" || echo "")
  
  if [[ -z "$extra_ports" ]]; then
    echo "No extra ports configured"
    exit 0
  fi

  # Split by comma and allow each port
  IFS=',' read -ra ports <<< "$extra_ports"
  for port in "${ports[@]}"; do
    port=$(echo "$port" | xargs)  # trim whitespace
    if [[ -n "$port" ]]; then
      ssh_sudo ufw allow "${port}/tcp"
      echo "Allowed port $port"
    fi
  done
}

enable() {
  # Check if UFW is already enabled
  local ufw_status=$(ssh_sudo ufw status | grep -q "Status: active" && echo "ACTIVE" || echo "INACTIVE")
  
  if [[ "$ufw_status" == "ACTIVE" ]]; then
    echo "UFW already enabled — skipping"
    return 0
  fi
  
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
