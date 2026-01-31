const { execSync } = require('child_process');
const path         = require('path');

// Resolve config lazily so circular deps can't bite us
let _cfg = null;
function cfg() {
  if (!_cfg) _cfg = require('./config').load();
  return _cfg;
}

const TIMEOUT_MS = 120_000; // 2 min per command — generous for apt install etc.

// ─── root login (password-based, only for step 2) ──────────────────────────
function sshRoot(command) {
  const { vps_ip, root_password } = cfg();
  const cmd = [
    'sshpass', `-p${root_password}`,
    'ssh',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'ConnectTimeout=10',
    `root@${vps_ip}`,
    command,
  ].join(' ');

  return execSync(cmd, { encoding: 'utf8', timeout: TIMEOUT_MS, stdio: ['pipe', 'pipe', 'pipe'] });
}

// ─── deployer login (key-based, from step 3 onward) ─────────────────────────
function sshDeploy(command) {
  const { vps_ip, ssh_key_path } = cfg();
  const cmd = [
    'ssh',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'ConnectTimeout=10',
    '-i', ssh_key_path,
    `deployer@${vps_ip}`,
    command,
  ].join(' ');

  return execSync(cmd, { encoding: 'utf8', timeout: TIMEOUT_MS, stdio: ['pipe', 'pipe', 'pipe'] });
}

// ─── deployer + sudo ────────────────────────────────────────────────────────
function sshSudo(command) {
  return sshDeploy(`sudo ${command}`);
}

// ─── scp helper (pull a file from VPS to local) ─────────────────────────────
function scpPull(remotePath, localPath) {
  const { vps_ip, ssh_key_path } = cfg();
  const cmd = [
    'scp',
    '-i', ssh_key_path,
    '-o', 'StrictHostKeyChecking=no',
    `deployer@${vps_ip}:${remotePath}`,
    localPath,
  ].join(' ');

  return execSync(cmd, { encoding: 'utf8', timeout: TIMEOUT_MS, stdio: ['pipe', 'pipe', 'pipe'] });
}

module.exports = { sshRoot, sshDeploy, sshSudo, scpPull };
