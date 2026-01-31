const { execSync } = require('child_process');
const path         = require('path');
const logger       = require('./logger');
const ui           = require('./ui');

const STEPS_DIR = path.join(__dirname, '..', 'steps');

/**
 * runStep({ label, script, fn })
 *
 * Runs a single sub-step. Two modes:
 *   • script + fn  → execSync("bash steps/<script> <fn>")   ← the normal path
 *   • fn (JS)      → calls fn() directly                    ← for inline JS steps (e.g. preflight)
 *
 * Shows a spinner while running, then ✔ or ✘.
 * Returns true on success, false on failure.
 */
async function runStep({ label, script, fn }) {
  const spinner = new ui.Spinner(label);
  spinner.start();

  try {
    if (script) {
      // Call the bash step file, passing the function name as $1.
      // The step file's main block dispatches on $1.
      const cmd = `bash "${path.join(STEPS_DIR, script)}" "${fn}"`;
      execSync(cmd, {
        encoding: 'utf8',
        timeout:  180_000, // 3 min — some steps (apt upgrade) are slow
        stdio:    ['pipe', 'pipe', 'pipe'],
      });
    } else if (typeof fn === 'function') {
      await fn();
    }

    spinner.stop();
    ui.printStepOk(label);
    logger.ok(label);
    return true;

  } catch (err) {
    spinner.stop();
    ui.printStepFail(label);

    const detail = err.stderr || err.stdout || err.message || 'unknown error';
    logger.error(`${label}: ${detail.trim()}`);
    return false;
  }
}

/**
 * runSection({ title, steps })
 *
 * steps = [{ label, script, fn }, ...]
 *
 * Prints the section header, runs each step, prints section result.
 * Returns { title, passed: bool }
 */
async function runSection({ title, steps }) {
  ui.printSection(title);

  let failed = 0;
  for (const step of steps) {
    const ok = await runStep(step);
    if (!ok) failed++;
  }

  const passed = failed === 0;
  passed ? ui.printSectionOk(title) : ui.printSectionFail(title);
  return { title, passed };
}

module.exports = { runStep, runSection };
