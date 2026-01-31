#!/usr/bin/env bash
# ─── Step 08: Docker ────────────────────────────────────────
# Sub-steps: install | add_group | verify_docker | verify_compose
# ────────────────────────────────────────────────────────────
set -euo pipefail

CFG="$(dirname "$0")/../config.yml"
VPS_IP=$(grep -m1 "^vps_ip:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
KEY_PATH=$(grep -m1 "^ssh_key_path:" "$CFG" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")

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
  ssh_sudo bash -c 'curl -fsSL https://get.docker.com | bash'
}

add_group() {
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
