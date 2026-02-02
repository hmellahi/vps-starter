#!/usr/bin/env bash
# ─── Step 12: Deploy Application Code ──────────────────────
# Sub-steps: clone_repo | copy_env | set_env_permissions
# ────────────────────────────────────────────────────────────
set -euo pipefail

# Load .env file
ENV_FILE="$(dirname "$0")/../.env"
LOCAL_ENV_TEMPLATE="$(dirname "$0")/../src/app/.env.example"

get_env() {
  grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^["'\'']\(.*\)["'\'']$/\1/' | sed "s|\$HOME|$HOME|"
}

VPS_IP=$(get_env "VPS_IP")
KEY_PATH=$(get_env "SSH_KEY_PATH")
REPO=$(get_env "GITHUB_REPO")
APP_DIR=$(get_env "APP_DIR_NAME")
GH_TOKEN=$(get_env "GITHUB_TOKEN" || echo "")

# Get DB credentials for .env substitution
POSTGRES_DB=$(get_env "POSTGRES_DB")
POSTGRES_USER=$(get_env "POSTGRES_USER")
POSTGRES_PASSWORD=$(get_env "POSTGRES_PASSWORD")
POSTGRES_PORT=$(get_env "POSTGRES_PORT")

ssh_deploy() {
  ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    root@"$VPS_IP" "$@"
}

# ─── sub-steps ──────────────────────────────────────────────

clone_repo() {
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
    git clone '${clone_url}' '${APP_DIR}'
  "
}

copy_env() {
  # Check if .env already exists on server
  local env_exists=$(ssh_deploy bash -c "
    if [[ -f /home/deployer/${APP_DIR}/.env ]]; then
      echo 'EXISTS'
    else
      echo 'NOT_EXISTS'
    fi
  " 2>/dev/null || echo "NOT_EXISTS")

  if [[ "$env_exists" == "EXISTS" ]]; then
    echo ".env already exists on server — skipping"
    return 0
  fi

  # Read the local .env.example template
  if [[ ! -f "$LOCAL_ENV_TEMPLATE" ]]; then
    echo "ERROR: $LOCAL_ENV_TEMPLATE not found locally" >&2
    exit 1
  fi

  # Create a temporary file with substituted values
  local temp_env=$(mktemp)

  # Process the template and replace variables
  while IFS= read -r line; do
    # Replace DATABASE_URL with actual values
    if [[ "$line" =~ ^DATABASE_URL= ]]; then
      echo "DATABASE_URL=\"postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${VPS_IP}:${POSTGRES_PORT}/${POSTGRES_DB}\"" >> "$temp_env"
    else
      # Copy other lines as-is (could add more substitutions here if needed)
      echo "$line" >> "$temp_env"
    fi
  done < "$LOCAL_ENV_TEMPLATE"

  # Copy the processed .env file to the server
  scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$temp_env" \
    root@"$VPS_IP":/home/deployer/"${APP_DIR}"/.env

  scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$temp_env" \
    root@"$VPS_IP":/home/deployer/"${APP_DIR}"/app/.env

  # Clean up temp file
  rm -f "$temp_env"

  echo "Copied and configured .env to server"
}

set_env_permissions() {
  # Check if .env exists before setting permissions
  local env_exists=$(ssh_deploy bash -c "
    if [[ -f /home/deployer/${APP_DIR}/.env ]]; then
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
