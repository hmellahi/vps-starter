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
SSH_KEY_PATH=$(get_env "SSH_KEY_PATH")

ssh_root() {
  local result
  local exit_code
  
  # Use SSH key if provided, otherwise fall back to password
  if [[ -n "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH" ]]; then
    result=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes root@"$VPS_IP" "$@" 2>&1)
    exit_code=$?
  elif [[ -n "$ROOT_PASS" ]]; then
    result=$(sshpass -p"$ROOT_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@"$VPS_IP" "$@" 2>&1)
    exit_code=$?
  else
    echo "❌ Neither SSH_KEY_PATH nor ROOT_PASSWORD is configured!" >&2
    exit 1
  fi
  
  # Print the output
  echo "$result"
  
  # If SSH failed, provide helpful error message
  if [[ $exit_code -ne 0 ]]; then
    if [[ -n "$SSH_KEY_PATH" ]]; then
      echo "❌ SSH key authentication failed. Check that:" >&2
      echo "   1. The key file exists: $SSH_KEY_PATH" >&2
      echo "   2. The key is authorized on the VPS for root user" >&2
      echo "   3. Test manually: ssh -i $SSH_KEY_PATH root@$VPS_IP" >&2
    else
      echo "❌ Password authentication failed. Check that:" >&2
      echo "   1. ROOT_PASSWORD is correct in .env" >&2
      echo "   2. Password authentication is enabled on the VPS" >&2
      echo "   3. Root login is permitted on the VPS" >&2
    fi
    return $exit_code
  fi
  
  return 0
}

# ─── sub-steps ──────────────────────────────────────────────

update_system() {
  ssh_root "apt-get update -qq && apt-get upgrade -y -qq"
}

create_deployer() {
  # Check if deployer user already exists
  local user_exists=$(ssh_root "id -u deployer >/dev/null 2>&1 && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$user_exists" == "EXISTS" ]]; then
    echo "User 'deployer' already exists — skipping"
    return 0
  fi
  
  # Create deployer user without password (will use SSH keys only)
  ssh_root "useradd -m -s /bin/bash deployer"
}

add_sudo() {
  # Check if deployer is already in sudo group
  local in_sudo=$(ssh_root "groups deployer | grep -q sudo && echo 'YES' || echo 'NO'")
  
  if [[ "$in_sudo" == "YES" ]]; then
    echo "User 'deployer' already in sudo group — skipping"
    return 0
  fi
  
  ssh_root "usermod -aG sudo deployer"
}

enable_passwordless_sudo() {
  # Check if passwordless sudo is already configured
  local sudo_configured=$(ssh_root "test -f /etc/sudoers.d/deployer && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$sudo_configured" == "EXISTS" ]]; then
    echo "Passwordless sudo already configured — skipping"
    return 0
  fi
  
  # Allow deployer to use sudo without password - secure for automation
  ssh_root "echo 'deployer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deployer && chmod 440 /etc/sudoers.d/deployer"
}

install_ssh_key() {
  # Get the SSH key path and read the public key
  local key_path
  key_path=$(get_env "SSH_KEY_PATH")
  local pub_key
  pub_key=$(cat "${key_path}.pub")
  
  # Check if the key is already installed
  local key_installed=$(ssh_root "grep -q '$pub_key' /home/deployer/.ssh/authorized_keys 2>/dev/null && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$key_installed" == "EXISTS" ]]; then
    echo "SSH key already installed — skipping"
    return 0
  fi
  
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
