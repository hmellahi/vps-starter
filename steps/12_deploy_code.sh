#!/usr/bin/env bash
# ─── Step 12: Deploy Application Code ──────────────────────
# Sub-steps: clone_repo | scaffold_env | set_env_permissions
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")
REPO=$(get_env "GITHUB_REPO")
APP_DIR=$(get_env "APP_DIR_NAME")
GH_TOKEN=$(get_env "GITHUB_TOKEN" || echo "")

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

clone_repo() {
  # Build the clone URL with token if provided
  local clone_url="$REPO"
  if [[ -n "$GH_TOKEN" ]]; then
    # Insert token into https URL: https://TOKEN@github.com/...
    clone_url=$(echo "$REPO" | sed "s|https://|https://${GH_TOKEN}@|")
  fi

  ssh_deploy bash -c "
    cd /home/deployer
    if [[ -d '${APP_DIR}' ]]; then
      echo 'Directory exists — pulling latest'
      cd '${APP_DIR}' && git pull
    else
      git clone '${clone_url}' '${APP_DIR}'
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
