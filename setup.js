#!/usr/bin/env node
// ============================================================
//  setup.js — VPS Deploy Orchestrator
//
//  Usage:  node setup.js   (or  npm run setup)
//
//  Reads .env → runs preflight → executes Steps 2–13
//  via the bash files in steps/. All UI lives here in JS;
//  the bash files are pure command runners.
// ============================================================

const { execSync } = require("child_process");
const config = require("./src/config");
const logger = require("./src/logger");
const ui = require("./src/ui");
const { runSection } = require("./src/runner");

// ─── section definitions ────────────────────────────────────────────────────
// Each step maps directly to a bash file + the sub-step function names inside it.

const SECTIONS = [
  {
    title: "STEP 2 — Initial Server Setup",
    steps: [
      {
        label: "Update system packages",
        script: "02_initial_setup.sh",
        fn: "update_system",
      },
      {
        label: "Create deployer user",
        script: "02_initial_setup.sh",
        fn: "create_deployer",
      },
      {
        label: "Add deployer to sudo group",
        script: "02_initial_setup.sh",
        fn: "add_sudo",
      },
      {
        label: "Enable passwordless sudo",
        script: "02_initial_setup.sh",
        fn: "enable_passwordless_sudo",
      },
      // {
      //   label: "Generate SSH key pair",
      //   script: "03_ssh_keys.sh",
      //   fn: "generate_keypair",
      // },
      // {
      //   label: "Install SSH key on server",
      //   script: "02_initial_setup.sh",
      //   fn: "install_ssh_key",
      // },
      // {
      //   label: "Verify passwordless SSH login",
      //   script: "03_ssh_keys.sh",
      //   fn: "verify_login",
      // },
    ],
  },
  // {
  //   title: 'STEP 3 — SSH Key Setup',
  //   steps: [
  //     { label: 'Generate ED25519 key pair',    script: '03_ssh_keys.sh', fn: 'generate_keypair' },
  //     { label: 'Copy public key to VPS',       script: '03_ssh_keys.sh', fn: 'copy_public_key'  },
  //     { label: 'Verify passwordless login',    script: '03_ssh_keys.sh', fn: 'verify_login'     },
  //   ],
  // },
  {
    title: "STEP 4 — Firewall (UFW)",
    steps: [
      {
        label: "Set default policies",
        script: "04_firewall.sh",
        fn: "set_defaults",
      },
      {
        label: "Allow SSH / HTTP / HTTPS",
        script: "04_firewall.sh",
        fn: "allow_core",
      },
      {
        label: "Allow extra ports (config)",
        script: "04_firewall.sh",
        fn: "allow_extra",
      },
      { label: "Enable UFW", script: "04_firewall.sh", fn: "enable" },
      {
        label: "Verify firewall status",
        script: "04_firewall.sh",
        fn: "verify",
      },
    ],
  },
  {
    title: "STEP 5 — Harden SSH",
    steps: [
      {
        label: "Patch sshd_config",
        script: "05_harden_ssh.sh",
        fn: "patch_config",
      },
      {
        label: "Validate sshd config syntax",
        script: "05_harden_ssh.sh",
        fn: "validate",
      },
      {
        label: "Restart SSH service",
        script: "05_harden_ssh.sh",
        fn: "restart",
      },
    ],
  },
  {
    title: "STEP 6 — Fail2Ban",
    steps: [
      { label: "Install Fail2Ban", script: "06_fail2ban.sh", fn: "install" },
      {
        label: "Write jail.local (from config)",
        script: "06_fail2ban.sh",
        fn: "write_jail",
      },
      {
        label: "Enable & start Fail2Ban",
        script: "06_fail2ban.sh",
        fn: "start",
      },
      {
        label: "Verify sshd jail active",
        script: "06_fail2ban.sh",
        fn: "verify",
      },
    ],
  },
  {
    title: "STEP 7 — Automatic Security Updates",
    steps: [
      {
        label: "Install unattended-upgrades",
        script: "07_auto_updates.sh",
        fn: "install",
      },
      {
        label: "Enable auto-update config",
        script: "07_auto_updates.sh",
        fn: "enable",
      },
      {
        label: "Verify unattended-upgrades",
        script: "07_auto_updates.sh",
        fn: "verify",
      },
    ],
  },
  {
    title: "STEP 8 — Docker",
    steps: [
      { label: "Install Docker", script: "08_docker.sh", fn: "install" },
      {
        label: "Add deployer to docker group",
        script: "08_docker.sh",
        fn: "add_group",
      },
      {
        label: "Verify docker version",
        script: "08_docker.sh",
        fn: "verify_docker",
      },
      {
        label: "Verify docker compose",
        script: "08_docker.sh",
        fn: "verify_compose",
      },
    ],
  },
  {
    title: "STEP 12 — Deploy Application Code",
    steps: [
      {
        label: "Clone / pull repository",
        script: "12_deploy_code.sh",
        fn: "clone_repo",
      },
      {
        label: "Copy & configure .env file",
        script: "12_deploy_code.sh",
        fn: "copy_env",
      },
      {
        label: "Set .env permissions (600)",
        script: "12_deploy_code.sh",
        fn: "set_env_permissions",
      },
    ],
  },
  // {
  //   title: "STEP 13 — Start App (Docker Compose)",
  //   steps: [
  //     {
  //       label: "Verify docker-compose.yml",
  //       script: "13_docker_compose.sh",
  //       fn: "verify_compose_file",
  //     },
  //     {
  //       label: "Build & start containers",
  //       script: "13_docker_compose.sh",
  //       fn: "build_and_up",
  //     },
  //     {
  //       label: "Show container status",
  //       script: "13_docker_compose.sh",
  //       fn: "show_status",
  //     },
  //     {
  //       label: "Show recent container logs",
  //       script: "13_docker_compose.sh",
  //       fn: "show_logs",
  //     },
  //   ],
  // },
];

// ─── preflight ──────────────────────────────────────────────────────────────
function preflight(cfg) {
  ui.printSection("Pre-Flight Checks");
  let ok = true;

  // 1. sshpass
  try {
    execSync("command -v sshpass", { stdio: "pipe" });
    ui.printPreflightOk("sshpass available");
  } catch {
    ui.printPreflightFail(
      "sshpass",
      "not installed — run: brew install sshpass  OR  apt install sshpass"
    );
    ok = false;
  }

  // 2. ssh-keygen
  try {
    execSync("which ssh-keygen", { stdio: "pipe" });
    ui.printPreflightOk("ssh-keygen available");
  } catch {
    ui.printPreflightFail("ssh-keygen", "not found");
    ok = false;
  }

  // 3. missing config fields
  if (cfg._missing && cfg._missing.length > 0) {
    for (const key of cfg._missing) {
      ui.printPreflightFail(`.env → ${key}`, "not filled in");
    }
    ok = false;
  } else {
    ui.printPreflightOk(`VPS IP: ${cfg.vps_ip}`);
    ui.printPreflightOk(`GitHub repo: ${cfg.github_repo}`);
  }

  if (ok) {
    ui.printSectionOk("Pre-Flight Checks");
  } else {
    ui.printSectionFail("Pre-Flight Checks");
  }
  return ok;
}

// ─── main ───────────────────────────────────────────────────────────────────
async function main() {
  logger.resetErrors();

  const cfg = config.load();

  ui.printBanner("VPS Setup & Deploy Automation");

  if (!preflight(cfg)) {
    process.exit(1);
  }

  const results = [];

  for (const section of SECTIONS) {
    const result = await runSection(section);
    results.push(result);
  }

  // ── summary ───────────────────────────────────────────────
  ui.printSummary(results);

  const allPassed = results.every((r) => r.passed);
  if (allPassed) {
    ui.printNextSteps(cfg.app_dir_name);
    logger.ok("Deploy complete.");
  } else {
    logger.error("Deploy finished with failures.");
    process.exit(1);
  }
}

main();
