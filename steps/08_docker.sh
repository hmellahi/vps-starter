#!/usr/bin/env bash
# ─── Step 08: Docker ────────────────────────────────────────
# Sub-steps: install | add_group | verify_docker | verify_compose
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

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

install() {
  # Check if Docker is already installed by trying to run it
  if ssh_sudo docker --version >/dev/null 2>&1; then
    echo "Docker already installed — skipping"
    return 0
  fi
  
  # Install Docker (download script then run — avoids pipe/quoting issues over SSH)
  echo "Installing Docker..."
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=30 \
    deployer@"$VPS_IP" 'sudo curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh'
  
  # Wait for docker service to be ready
  sleep 3
  
  # Verify installation succeeded
  if ! ssh_sudo docker --version; then
    echo "ERROR: Docker installation failed" >&2
    return 1
  fi
  
  echo "Docker installed successfully"
}

add_group() {
  # Wait a moment for Docker to create the docker group
  sleep 2
  
  # Check if docker group exists
  local docker_group_exists=$(ssh_sudo "getent group docker >/dev/null 2>&1 && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$docker_group_exists" != "EXISTS" ]]; then
    echo "Docker group doesn't exist, creating it..."
    ssh_sudo groupadd docker || true
  fi
  
  # Check if deployer is already in docker group
  local in_docker=$(ssh_sudo "groups deployer | grep -q docker && echo 'YES' || echo 'NO'")
  
  if [[ "$in_docker" == "YES" ]]; then
    echo "User 'deployer' already in docker group — skipping"
    return 0
  fi
  
  ssh_sudo usermod -aG docker deployer
}

verify_docker() {
  # Try with sudo (always works regardless of group membership)
  ssh_sudo docker version
}

verify_compose() {
  # Try with sudo (always works regardless of group membership)
  ssh_sudo docker compose version
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  install)         install         ;;
  add_group)       add_group       ;;
  verify_docker)   verify_docker   ;;
  verify_compose)  verify_compose  ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
