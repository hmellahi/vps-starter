#!/usr/bin/env bash
# ─── Step 13: Start App (Docker Compose) ───────────────────
# Sub-steps: verify_compose_file | build_and_up | show_status | show_logs
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")
APP_DIR=$(get_env "APP_DIR_NAME")
REMOTE_APP="/home/deployer/${APP_DIR}"

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

verify_compose_file() {
  ssh_deploy bash -c "
    if [[ ! -f ${REMOTE_APP}/docker-compose.yml ]] && [[ ! -f ${REMOTE_APP}/docker-compose.yaml ]]; then
      echo 'docker-compose.yml not found in ${REMOTE_APP}' >&2
      exit 1
    fi
    echo 'docker-compose.yml found'
  "
}

build_and_up() {
  ssh_deploy bash -c "
    cd ${REMOTE_APP}
    sg docker -c 'docker compose build --progress=plain'
    sg docker -c 'docker compose up -d'
  "
}

show_status() {
  ssh_deploy bash -c "cd ${REMOTE_APP} && sg docker -c 'docker compose ps'"
}

show_logs() {
  ssh_deploy bash -c "cd ${REMOTE_APP} && sg docker -c 'docker compose logs --tail=30'"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  verify_compose_file) verify_compose_file ;;
  build_and_up)        build_and_up        ;;
  show_status)         show_status         ;;
  show_logs)           show_logs           ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
