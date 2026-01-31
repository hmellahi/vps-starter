#!/usr/bin/env bash
# ─── Step 07: Automatic Security Updates ───────────────────
# Sub-steps: install | enable | verify
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

install() {
  ssh_sudo apt-get install -y -qq unattended-upgrades
}

enable() {
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
