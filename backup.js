#!/usr/bin/env node
// ============================================================
//  backup.js — Standalone VPS Backup
//
//  Usage:  node backup.js   (or  npm run backup)
//
//  Downloads a full snapshot of your VPS app into
//  ./backups/<timestamp>/  and writes a MANIFEST.txt.
// ============================================================

const { execSync } = require('child_process');
const fs           = require('fs');
const path         = require('path');
const config       = require('./src/config');
const logger       = require('./src/logger');
const ui           = require('./src/ui');
const { runSection } = require('./src/runner');

const ROOT       = __dirname;
const BACKUPS    = path.join(ROOT, 'backups');
const TIMESTAMP  = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const BACKUP_DIR = path.join(BACKUPS, TIMESTAMP);

// ─── ensure backup dir exists ───────────────────────────────────────────────
fs.mkdirSync(BACKUP_DIR, { recursive: true });

// ─── shared state (DB type detected in first step, used by second) ─────────
let detectedDbType = 'none';

// ─── inline JS steps (these need access to local state / fs) ───────────────

async function detectDatabase() {
  const cfg = config.load();
  const { sshDeploy } = require('./src/ssh');
  const appPath = `/home/deployer/${cfg.app_dir_name}`;

  let content = '';
  try {
    content = sshDeploy(`cat ${appPath}/docker-compose.yml`);
  } catch {
    // file might not exist yet
  }

  if (/postgres/i.test(content))       detectedDbType = 'postgres';
  else if (/mysql|mariadb/i.test(content)) detectedDbType = 'mysql';
  else                                     detectedDbType = 'none';

  console.log(`    ${ui.C.dim}detected: ${detectedDbType}${ui.C.reset}`);
}

async function dumpDatabase() {
  if (detectedDbType === 'none') {
    console.log(`    ${ui.C.dim}no database — skipped${ui.C.reset}`);
    return;
  }

  const cfg = config.load();
  const { sshDeploy } = require('./src/ssh');
  const appPath = `/home/deployer/${cfg.app_dir_name}`;
  const outFile = path.join(BACKUP_DIR, 'database.dump');

  // We run the dump command remotely and capture stdout into the local file.
  // The container detection + dump command is all one remote script.
  const script = detectedDbType === 'postgres'
    ? `cd ${appPath} && \
       PG=$(sg docker -c 'docker compose ps -q' | while read c; do sg docker -c "docker inspect --format='{{.Name}}' $c"; done | grep -i postgres | head -1 | tr -d '/') && \
       sg docker -c "docker exec $PG pg_dump -U postgres --no-owner -Fc postgres"`
    : `cd ${appPath} && \
       MY=$(sg docker -c 'docker compose ps -q' | while read c; do sg docker -c "docker inspect --format='{{.Name}}' $c"; done | grep -i mysql | head -1 | tr -d '/') && \
       sg docker -c "docker exec $MY mysqldump -u root --all-databases"`;

  const output = sshDeploy(`bash -c '${script}'`);
  fs.writeFileSync(outFile, output);

  const size = (fs.statSync(outFile).size / 1024).toFixed(1);
  console.log(`    ${ui.C.dim}saved ${size} KB${ui.C.reset}`);
}

async function backupAppFiles() {
  const cfg = config.load();
  const { sshDeploy, scpPull } = require('./src/ssh');
  const remoteTar = `/tmp/app_backup_${TIMESTAMP}.tar.gz`;

  sshDeploy(
    `tar -czf "${remoteTar}" --exclude=node_modules --exclude=.git --exclude=.next -C /home/deployer "${cfg.app_dir_name}"`
  );

  scpPull(remoteTar, path.join(BACKUP_DIR, 'app_files.tar.gz'));
  sshDeploy(`rm -f "${remoteTar}"`);

  const size = (fs.statSync(path.join(BACKUP_DIR, 'app_files.tar.gz')).size / 1024).toFixed(1);
  console.log(`    ${ui.C.dim}saved ${size} KB${ui.C.reset}`);
}

async function backupDockerVolumes() {
  const cfg = config.load();
  const { sshDeploy, scpPull } = require('./src/ssh');
  const appPath = `/home/deployer/${cfg.app_dir_name}`;

  let volList = '';
  try {
    volList = sshDeploy(
      `cd ${appPath} && sg docker -c "docker volume ls -q --filter driver=local" | grep "${cfg.app_dir_name}" || true`
    ).trim();
  } catch {
    // no volumes
  }

  if (!volList) {
    console.log(`    ${ui.C.dim}no named volumes — skipped${ui.C.reset}`);
    return;
  }

  const volumes = volList.split('\n').filter(Boolean);
  for (const vol of volumes) {
    const clean = vol.replace(/\//g, '_');
    const remoteTar = `/tmp/vol_${clean}.tar.gz`;

    sshDeploy(
      `sg docker -c "docker run --rm -v ${vol}:/data -v /tmp:/backup alpine tar -czf ${remoteTar} -C /data ."`
    );
    scpPull(remoteTar, path.join(BACKUP_DIR, `vol_${clean}.tar.gz`));
    sshDeploy(`rm -f "${remoteTar}"`);
    console.log(`    ${ui.C.dim}volume: ${vol}${ui.C.reset}`);
  }
}

async function writeManifest() {
  const cfg    = config.load();
  const files  = fs.readdirSync(BACKUP_DIR).filter(f => f !== 'MANIFEST.txt');
  const lines  = files.map(f => {
    const size = (fs.statSync(path.join(BACKUP_DIR, f)).size / 1024).toFixed(1);
    return `  ${f.padEnd(30)} ${size} KB`;
  });

  const manifest = [
    '============================================================',
    '  VPS Backup Manifest',
    `  Created : ${new Date().toLocaleString()}`,
    `  VPS IP   : ${cfg.vps_ip}`,
    `  App      : ${cfg.app_dir_name}`,
    '============================================================',
    '',
    'Contents:',
    ...lines,
    '',
    'Restore notes:',
    '  database.dump     → pg_restore or mysql < database.dump',
    '  app_files.tar.gz  → extract into /home/deployer/',
    '  vol_*.tar.gz      → mount volume, extract inside',
    '============================================================',
  ].join('\n');

  fs.writeFileSync(path.join(BACKUP_DIR, 'MANIFEST.txt'), manifest);
  console.log(`    ${ui.C.dim}manifest written${ui.C.reset}`);
}

// ─── section definition ─────────────────────────────────────────────────────
const BACKUP_SECTION = {
  title: 'Backup',
  steps: [
    { label: 'Detect database type',       fn: detectDatabase      },
    { label: 'Dump database',              fn: dumpDatabase         },
    { label: 'Backup application files',   fn: backupAppFiles       },
    { label: 'Backup Docker volumes',      fn: backupDockerVolumes  },
    { label: 'Write backup manifest',      fn: writeManifest        },
  ],
};

// ─── main ───────────────────────────────────────────────────────────────────
async function main() {
  logger.resetErrors();
  const cfg = config.load();

  ui.printBanner('VPS Backup');
  console.log(`  ${ui.C.dim}Target : ${cfg.vps_ip}${ui.C.reset}`);
  console.log(`  ${ui.C.dim}Output : ${BACKUP_DIR}${ui.C.reset}`);

  const result = await runSection(BACKUP_SECTION);

  if (result.passed) {
    console.log('');
    console.log(`  ${ui.C.green}${ui.C.bold}✔  Backup complete!${ui.C.reset}`);
    console.log(`  ${ui.C.dim}Location: ${BACKUP_DIR}${ui.C.reset}`);
    console.log('');
  } else {
    console.log('');
    console.log(`  ${ui.C.red}${ui.C.bold}✘  Backup failed — check errors.txt${ui.C.reset}`);
    process.exit(1);
  }
}

main();
