const fs   = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const os   = require('os');

const CONFIG_PATH = path.join(__dirname, '..', 'config.yml');

// Fields the user must fill in before anything runs.
const REQUIRED = ['vps_ip', 'root_password', 'deployer_password', 'github_repo', 'app_dir_name'];

// Placeholder values that count as "not filled in".
const PLACEHOLDERS = ['YOUR_VPS_IP', 'YOUR_ROOT_PASSWORD', 'YOUR_DEPLOYER_PASSWORD', 'YOUR_USER'];

function load() {
  const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
  const cfg = yaml.load(raw);

  // Expand $HOME in ssh_key_path
  if (cfg.ssh_key_path) {
    cfg.ssh_key_path = cfg.ssh_key_path.replace('$HOME', os.homedir());
  }

  // Validate
  const missing = [];
  for (const key of REQUIRED) {
    const val = String(cfg[key] || '');
    if (!val || PLACEHOLDERS.some(p => val.includes(p))) {
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
