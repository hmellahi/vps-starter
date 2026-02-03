#!/usr/bin/env bash
# ─── Step 12: Deploy Application Code ──────────────────────
# Sub-steps: clone_repo | copy_env | set_env_permissions
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
LOCAL_APP_ENV_DIR="$(dirname "$0")/../src/app"
# Use actual .env if it exists (with real values), otherwise fall back to .env.example template
LOCAL_ENV_TEMPLATE="$LOCAL_APP_ENV_DIR/.env"
[[ -f "$LOCAL_APP_ENV_DIR/.env" ]] || LOCAL_ENV_TEMPLATE="$LOCAL_APP_ENV_DIR/.env.example"

get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")
REPO=$(get_env "GITHUB_REPO")
APP_DIR=$(get_env "APP_DIR_NAME")
GH_TOKEN=$(get_env "GITHUB_TOKEN" 2>/dev/null) || true
GH_TOKEN=${GH_TOKEN:-}

# DB credentials for .env substitution (optional — only needed for copy_env)
POSTGRES_DB=$(get_env "POSTGRES_DB" 2>/dev/null) || true
POSTGRES_USER=$(get_env "POSTGRES_USER" 2>/dev/null) || true
POSTGRES_PASSWORD=$(get_env "POSTGRES_PASSWORD" 2>/dev/null) || true
POSTGRES_PORT=$(get_env "POSTGRES_PORT" 2>/dev/null) || true
POSTGRES_DB=${POSTGRES_DB:-}
POSTGRES_USER=${POSTGRES_USER:-}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}
POSTGRES_PORT=${POSTGRES_PORT:-5432}

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" "$@"
}

ssh_sudo() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    deployer@"$VPS_IP" sudo "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

clone_repo() {
  if [[ -z "$REPO" || -z "$APP_DIR" ]] || [[ "$REPO" == *"your-username"* || "$REPO" == *"your-repo"* || "$APP_DIR" == "your-app-name" ]]; then
    echo "ERROR: Set GITHUB_REPO and APP_DIR_NAME in .env to a real repo URL and folder name." >&2
    echo "Example: GITHUB_REPO=https://github.com/user/myapp  APP_DIR_NAME=myapp" >&2
    exit 1
  fi

  # Check if repo already exists and has correct remote
  local repo_status=$(ssh_deploy bash -c "
    if [[ -d /home/deployer/${APP_DIR}/.git ]]; then
      cd /home/deployer/${APP_DIR}
      remote_url=\$(git remote get-url origin 2>/dev/null || echo '')
      if [[ \"\$remote_url\" == *'${REPO##*/}'* ]]; then
        echo 'EXISTS'
      else
        echo 'WRONG_REPO'
      fi
    else
      echo 'NOT_EXISTS'
    fi
  " 2>/dev/null || echo "NOT_EXISTS")

  if [[ "$repo_status" == "EXISTS" ]]; then
    echo "Repository already cloned — pulling latest"
    ssh_deploy bash -c "cd /home/deployer/${APP_DIR} && git pull"
    return 0
  fi

  # Build the clone URL with token if provided
  local clone_url="$REPO"
  if [[ -n "$GH_TOKEN" ]]; then
    # Insert token into https URL: https://TOKEN@github.com/...
    clone_url=$(echo "$REPO" | sed "s|https://|https://${GH_TOKEN}@|")
  fi

  ssh_deploy bash -c "
    cd /home/deployer
    if [[ -d '${APP_DIR}' ]]; then
      echo 'Directory exists but not a git repo — removing and cloning fresh'
      rm -rf '${APP_DIR}'
    fi
    echo 'Cloning repository...' ${clone_url}
    git clone '${clone_url}' '${APP_DIR}'
  "
}

copy_env() {
  # Need .env or .env.example in src/app to copy
  if [[ ! -f "$LOCAL_ENV_TEMPLATE" ]]; then
    echo "ERROR: No .env found. Add src/app/.env (with real values) or src/app/.env.example" >&2
    exit 1
  fi

  echo "Copying .env from: $LOCAL_ENV_TEMPLATE"
  
  # Copy the .env file directly to the server (with real values as-is)
  scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$LOCAL_ENV_TEMPLATE" \
    deployer@"$VPS_IP":/home/deployer/"${APP_DIR}"/.env

  scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$LOCAL_ENV_TEMPLATE" \
    deployer@"$VPS_IP":/home/deployer/"${APP_DIR}"/app/.env

  echo "✓ Copied .env to server (from $(basename "$LOCAL_ENV_TEMPLATE"))"
}

set_env_permissions() {
  # Check if .env exists before setting permissions
  local env_exists=$(ssh_deploy bash -c "
    if [[ -f /home/deployer/${APP_DIR}/.env && -f /home/deployer/${APP_DIR}/app/.env ]]; then
      echo 'EXISTS'
    else
      echo 'NOT_EXISTS'
    fi
  " 2>/dev/null || echo "NOT_EXISTS")

  if [[ "$env_exists" == "NOT_EXISTS" ]]; then
    echo ".env does not exist — skipping permission change"
    return 0
  fi

  # Check if permissions are already correct (600)
  local perms=$(ssh_deploy stat -c '%a' "/home/deployer/${APP_DIR}/.env" 2>/dev/null || echo "000")

  if [[ "$perms" == "600" ]]; then
    echo ".env permissions already set to 600 — skipping"
    return 0
  fi

  ssh_deploy chmod 600 "/home/deployer/${APP_DIR}/.env"
  echo "Set .env permissions to 600"
}

# ─── dispatch ───────────────────────────────────────────────
case "${1:-}" in
  clone_repo)          clone_repo          ;;
  copy_env)            copy_env            ;;
  set_env_permissions) set_env_permissions ;;
  # Legacy support for old name
  scaffold_env)        copy_env            ;;
  *) echo "Unknown sub-step: $1" >&2; exit 1 ;;
esac
