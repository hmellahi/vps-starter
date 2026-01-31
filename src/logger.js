const fs   = require('fs');
const path = require('path');

const ROOT      = path.join(__dirname, '..');
const LOG_PATH  = path.join(ROOT, 'deploy.log');
const ERR_PATH  = path.join(ROOT, 'errors.txt');

function timestamp() {
  return new Date().toLocaleTimeString('en-GB', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function isoStamp() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

// Always appends to deploy.log
function _log(level, msg) {
  const line = `[${timestamp()}] [${level}] ${msg}\n`;
  fs.appendFileSync(LOG_PATH, line);
}

function info(msg)  { _log('INFO',  msg); }
function warn(msg)  { _log('WARN',  msg); }
function ok(msg)    { _log('OK',    msg); }

// Logs to both deploy.log AND errors.txt
function error(msg) {
  _log('ERROR', msg);
  fs.appendFileSync(ERR_PATH, `${isoStamp()} | ${msg}\n`);
}

// Call once at the start of a run to wipe errors.txt clean
function resetErrors() {
  fs.writeFileSync(ERR_PATH, '');
}

module.exports = { info, warn, ok, error, resetErrors };
