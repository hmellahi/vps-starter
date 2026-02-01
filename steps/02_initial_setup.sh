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
  # Create deployer user without password (will use SSH keys only)
  ssh_root "useradd -m -s /bin/bash deployer || true"
}

add_sudo() {
  ssh_root "usermod -aG sudo deployer"
}

enable_passwordless_sudo() {
  # Allow deployer to use sudo without password - secure for automation
  ssh_root "echo 'deployer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deployer && chmod 440 /etc/sudoers.d/deployer"
}

install_ssh_key() {
  # Get the SSH key path and read the public key
  local key_path
  key_path=$(grep -m1 "^ssh_key_path:" "$(dirname "$0")/../config.yml" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")
  local pub_key
  pub_key=$(cat "${key_path}.pub")
  
  # Install the public key directly as root (no password needed!)
  ssh_root "mkdir -p /home/deployer/.ssh && \
            echo '$pub_key' > /home/deployer/.ssh/authorized_keys && \
            chown -R deployer:deployer /home/deployer/.ssh && \
            chmod 700 /home/deployer/.ssh && \
            chmod 600 /home/deployer/.ssh/authorized_keys"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  update_system)            update_system            ;;
  create_deployer)          create_deployer          ;;
  add_sudo)                 add_sudo                 ;;
  enable_passwordless_sudo) enable_passwordless_sudo ;;
  install_ssh_key)          install_ssh_key          ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
