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
  # Check if Docker is already installed
  local docker_installed=$(ssh_deploy "command -v docker >/dev/null 2>&1 && echo 'EXISTS' || echo 'NOT_EXISTS'")
  
  if [[ "$docker_installed" == "EXISTS" ]]; then
    echo "Docker already installed — skipping"
    return 0
  fi
  
  ssh_sudo bash -c 'curl -fsSL https://get.docker.com | bash'
}

add_group() {
  # Check if deployer is already in docker group
  local in_docker=$(ssh_deploy "groups | grep -q docker && echo 'YES' || echo 'NO'")
  
  if [[ "$in_docker" == "YES" ]]; then
    echo "User 'deployer' already in docker group — skipping"
    return 0
  fi
  
  ssh_sudo usermod -aG docker deployer
}

verify_docker() {
  # sg runs the command inside the docker group without a new login shell
  ssh_deploy bash -c 'sg docker -c "docker version"'
}

verify_compose() {
  ssh_deploy bash -c 'sg docker -c "docker compose version"'
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  install)         install         ;;
  add_group)       add_group       ;;
  verify_docker)   verify_docker   ;;
  verify_compose)  verify_compose  ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
