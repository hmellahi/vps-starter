const fs   = require('fs');
const path = require('path');
const os   = require('os');

const ENV_PATH = path.join(__dirname, '..', '.env');

// Fields the user must fill in before anything runs.
const REQUIRED = ['VPS_IP', 'ROOT_PASSWORD', 'GITHUB_REPO', 'APP_DIR_NAME', 'GITHUB_TOKEN'];

// Placeholder values that count as "not filled in".
const PLACEHOLDERS = ['your-vps-ip-here', 'your-root-password-here', 'your-username', 'your-repo', 'your-app-name', 'your-github-token-here'];

function parseEnv(content) {
  const env = {};
  const lines = content.split('\n');
  
  for (const line of lines) {
    // Skip comments and empty lines
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    
    // Parse KEY=VALUE
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      
      // Remove quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) || 
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }
      
      env[key] = value;
    }
  }
  
  return env;
}

function load() {
  if (!fs.existsSync(ENV_PATH)) {
    console.error('\n❌ .env file not found!');
    console.error('📝 Copy .env.example to .env and fill in your values:\n');
    console.error('   cp .env.example .env\n');
    process.exit(1);
  }

  const raw = fs.readFileSync(ENV_PATH, 'utf8');
  const env = parseEnv(raw);

  // Build config object with snake_case keys for backward compatibility
  const cfg = {
    vps_ip: env.VPS_IP,
    root_password: env.ROOT_PASSWORD,
    ssh_key_path: env.SSH_KEY_PATH,
    github_repo: env.GITHUB_REPO,
    github_token: env.GITHUB_TOKEN,
    app_dir_name: env.APP_DIR_NAME,
    app_port: env.APP_PORT || '3000',
    extra_ports: env.EXTRA_PORTS ? env.EXTRA_PORTS.split(',').map(p => p.trim()).filter(Boolean) : [],
    fail2ban_bantime: env.FAIL2BAN_BANTIME || '3600',
    fail2ban_findtime: env.FAIL2BAN_FINDTIME || '600',
    fail2ban_maxretry: env.FAIL2BAN_MAXRETRY || '5',
  };

  // Expand $HOME in ssh_key_path
  if (cfg.ssh_key_path) {
    cfg.ssh_key_path = cfg.ssh_key_path.replace('$HOME', os.homedir());
  }

  // Validate
  const missing = [];
  for (const key of REQUIRED) {
    const snakeKey = key.toLowerCase();
    const val = String(cfg[snakeKey] || '');
    if (!val || PLACEHOLDERS.some(p => val.toLowerCase().includes(p.toLowerCase()))) {
      missing.push(key);
    }
  }

  if (missing.length > 0) {
    // Return the config anyway — the caller (preflight) will surface the errors nicely.
    cfg._missing = missing;
  }

  return cfg;
}

module.exports = { load };
