// ─── colours ────────────────────────────────────────────────────────────────
const C = {
  reset:  '\x1b[0m',
  bold:   '\x1b[1m',
  dim:    '\x1b[2m',
  red:    '\x1b[31m',
  green:  '\x1b[32m',
  yellow: '\x1b[33m',
  cyan:   '\x1b[36m',
};

// ─── spinner ────────────────────────────────────────────────────────────────
// A simple text-based spinner that overwrites the current line.
const SPIN_FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

class Spinner {
  constructor(label) {
    this.label  = label;
    this.idx    = 0;
    this.active = false;
  }

  start() {
    this.active = true;
    this._tick();
  }

  _tick() {
    if (!this.active) return;
    const frame = SPIN_FRAMES[this.idx % SPIN_FRAMES.length];
    process.stdout.write(`\r  ${C.cyan}${frame}${C.reset} ${C.dim}${this.label}${C.reset}`);
    this.idx++;
    this._timer = setTimeout(() => this._tick(), 80);
  }

  stop() {
    this.active = false;
    clearTimeout(this._timer);
    // Clear the line so the caller can print the final ✔ or ✘
    process.stdout.write('\r' + ' '.repeat(process.stdout.columns || 80) + '\r');
  }
}

// ─── section header ─────────────────────────────────────────────────────────
function printSection(title) {
  const w = 60;
  const inner = ` ${title} `.padEnd(w - 2);
  console.log('');
  console.log(`${C.bold}${C.cyan}╔${'═'.repeat(w - 2)}╗${C.reset}`);
  console.log(`${C.bold}${C.cyan}║${C.reset}  ${C.bold}${title}${C.reset}${' '.repeat(w - 4 - title.length)}${C.bold}${C.cyan}║${C.reset}`);
  console.log(`${C.bold}${C.cyan}╚${'═'.repeat(w - 2)}╝${C.reset}`);
}

// ─── step result lines ──────────────────────────────────────────────────────
function printStepOk(label) {
  console.log(`  ${C.green}✔${C.reset} ${label}`);
}

function printStepFail(label) {
  console.log(`  ${C.red}✘${C.reset} ${label}`);
}

function printStepSkipped(label, reason) {
  console.log(`  ${C.yellow}○${C.reset} ${label} ${C.dim}— ${reason}${C.reset}`);
}

// ─── section result ─────────────────────────────────────────────────────────
function printSectionOk(title) {
  console.log('');
  console.log(`  ${C.green}${C.bold}✔  ${title} — completed${C.reset}`);
  console.log(`  ${C.dim}─────────────────────────────────────────────${C.reset}`);
}

function printSectionFail(title) {
  console.log('');
  console.log(`  ${C.red}${C.bold}✘  ${title} — failed (see errors.txt)${C.reset}`);
  console.log(`  ${C.dim}─────────────────────────────────────────────${C.reset}`);
}

// ─── preflight ──────────────────────────────────────────────────────────────
function printPreflightOk(label) { printStepOk(label); }
function printPreflightFail(label, reason) {
  console.log(`  ${C.red}✘${C.reset} ${label} ${C.dim}— ${reason}${C.reset}`);
}

// ─── banner ─────────────────────────────────────────────────────────────────
function printBanner(subtitle) {
  console.log('');
  console.log(`${C.bold}${C.cyan}  ██╗  ██╗██████╗ ███████╗     ██████╗ ███████╗██╗      ██╗   ██╗██╗${C.reset}`);
  console.log(`${C.bold}${C.cyan}  ██║  ██║██╔══██╗██╔════╝    ██╔═══██╗██╔════╝██║      ██║   ██║██║${C.reset}`);
  console.log(`${C.bold}${C.cyan}  ███████║██║  ██║█████╗      ██║   ██║█████╗  ██║      ██║   ██║██║${C.reset}`);
  console.log(`${C.bold}${C.cyan}  ██╔══██║██║  ██║██╔══╝      ██║   ██║██╔══╝  ██║      ██║   ██║╚═╝${C.reset}`);
  console.log(`${C.bold}${C.cyan}  ██║  ██║██████╔╝███████╗    ╚██████╔╝███████╗███████╗╚██████╔╝██╗${C.reset}`);
  console.log(`${C.bold}${C.cyan}  ╚═╝  ╚═╝╚═════╝ ╚══════╝     ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚═╝${C.reset}`);
  console.log(`  ${C.dim}${subtitle}${C.reset}`);
  console.log('');
}

// ─── final summary board ────────────────────────────────────────────────────
// sections = [{ title, passed: bool }]
function printSummary(sections) {
  const w = 60;
  const passed = sections.filter(s => s.passed).length;
  const total  = sections.length;
  const allOk  = passed === total;

  console.log('');
  console.log(`${C.bold}${C.cyan}╔${'═'.repeat(w - 2)}╗${C.reset}`);
  console.log(`${C.bold}${C.cyan}║${C.reset}  ${C.bold}DEPLOYMENT SUMMARY${C.reset}${' '.repeat(w - 22)}${C.bold}${C.cyan}║${C.reset}`);
  console.log(`${C.bold}${C.cyan}╠${'═'.repeat(w - 2)}╣${C.reset}`);

  for (const s of sections) {
    const icon = s.passed ? `${C.green}✔${C.reset}` : `${C.red}✘${C.reset}`;
    const name = s.title.padEnd(w - 8);
    console.log(`${C.bold}${C.cyan}║${C.reset}  ${icon} ${name}${C.bold}${C.cyan}║${C.reset}`);
  }

  console.log(`${C.bold}${C.cyan}╠${'═'.repeat(w - 2)}╣${C.reset}`);

  const scoreLabel = `  ${passed} / ${total} sections passed`;
  console.log(`${C.bold}${C.cyan}║${C.reset}${scoreLabel}${' '.repeat(w - 2 - scoreLabel.length)}${C.bold}${C.cyan}║${C.reset}`);
  console.log(`${C.bold}${C.cyan}╚${'═'.repeat(w - 2)}╝${C.reset}`);
  console.log('');

  if (allOk) {
    console.log(`  ${C.green}${C.bold}✔  All sections passed!${C.reset}`);
  } else {
    console.log(`  ${C.red}${C.bold}✘  Some sections failed — check errors.txt${C.reset}`);
  }
  console.log('');
}

// ─── next-steps hint (setup-specific) ──────────────────────────────────────
function printNextSteps(appDir) {
  console.log(`  ${C.dim}Next steps:${C.reset}`);
  console.log(`    1. Populate ${C.yellow}/home/deployer/${appDir}/.env${C.reset} on the VPS`);
  console.log(`    2. Run  docker compose restart  if you changed .env after first start`);
  console.log(`    3. Continue with SSL (Step 15), DNS (Step 17), etc.`);
  console.log('');
}

module.exports = {
  C,
  Spinner,
  printSection,
  printStepOk,
  printStepFail,
  printStepSkipped,
  printSectionOk,
  printSectionFail,
  printPreflightOk,
  printPreflightFail,
  printBanner,
  printSummary,
  printNextSteps,
};
