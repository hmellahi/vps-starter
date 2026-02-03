#!/usr/bin/env bash
# ─── Step 07: Automatic Security Updates ───────────────────
# Sub-steps: install | enable | verify
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
  # Check if unattended-upgrades is already installed
  local uu_installed=$(ssh_sudo "dpkg -l | grep -q unattended-upgrades && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$uu_installed" == "EXISTS" ]]; then
    echo "unattended-upgrades already installed — skipping"
    return 0
  fi
  
  ssh_sudo apt-get install -y -qq unattended-upgrades
}

enable() {
  # Check if auto-upgrade config already exists
  local config_exists=$(ssh_sudo "test -f /etc/apt/apt.conf.d/20auto-upgrade && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$config_exists" == "EXISTS" ]]; then
    echo "Auto-upgrade already configured — skipping"
    return 0
  fi
  
  ssh_sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrade <<EOF
Acquire::http::Download-Limit "1M";
Acquire::http::Dl-Limit "50";
APT::Immediate-Configuration true;
Unattended-Upgrade::Enable-Syslog true;
EOF'
  ssh_sudo dpkg-reconfigure --frontend=noninteractive unattended-upgrades <<< "0"
}

verify() {
  ssh_sudo systemctl status unattended-upgrades
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  install) install ;;
  enable)  enable  ;;
  verify)  verify  ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
