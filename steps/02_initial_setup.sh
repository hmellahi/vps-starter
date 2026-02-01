#!/usr/bin/env bash
# ─── Step 02: Initial Server Setup ─────────────────────────
# Sub-steps: update_system | create_deployer | add_sudo
# Called by the JS runner as: bash 02_initial_setup.sh <sub-step>
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env file not found! Copy .env.example to .env first." >&2
  exit 1
fi

# Parse .env (ignore comments and empty lines)
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
ROOT_PASS=$(get_env "ROOT_PASSWORD")

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
  key_path=$(get_env "SSH_KEY_PATH")
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
