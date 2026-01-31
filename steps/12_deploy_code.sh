#!/usr/bin/env bash
# ─── Step 12: Deploy Application Code ──────────────────────
# Sub-steps: clone_repo | scaffold_env | set_env_permissions
# ────────────────────────────────────────────────────────────
set -euo pipefail

CFG="$(dirname "$0")/../config.yml"
VPS_IP=$(grep -m1 "^vps_ip:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
KEY_PATH=$(grep -m1 "^ssh_key_path:" "$CFG" | sed 's/^[^:]*: *//;s/"//g' | sed "s|\$HOME|$HOME|")
REPO=$(grep -m1 "^github_repo:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')
APP_DIR=$(grep -m1 "^app_dir_name:" "$CFG" | sed 's/^[^:]*: *//;s/"//g')

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

clone_repo() {
  ssh_deploy bash -c "
    cd /home/deployer
    if [[ -d '${APP_DIR}' ]]; then
      echo 'Directory exists — pulling latest'
      cd '${APP_DIR}' && git pull
    else
      git clone '${REPO}'
    fi
  "
}

scaffold_env() {
  ssh_deploy bash -c "
    ENV=/home/deployer/${APP_DIR}/.env
    if [[ ! -f \"\$ENV\" ]]; then
      echo '# Fill in your environment variables here' > \"\$ENV\"
      echo 'Created .env'
    else
      echo '.env already exists — skipping'
    fi
  "
}

set_env_permissions() {
  ssh_deploy chmod 600 "/home/deployer/${APP_DIR}/.env"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  clone_repo)          clone_repo          ;;
  scaffold_env)        scaffold_env        ;;
  set_env_permissions) set_env_permissions ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
