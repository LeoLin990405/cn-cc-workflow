// Electron main process: window + exec fuguectl via execFile (no shell, no separate server).
const { app, BrowserWindow, ipcMain } = require('electron');
const { execFile } = require('node:child_process');
const path = require('node:path');

const FUGUE = '/Users/jiangyu/workspace/agent/FuguNano/orchestration/fuguectl/fuguectl';
const ROOT = '/Users/jiangyu/workspace/agent/FuguNano';
const ENV = { ...process.env, PATH: `/Applications/Codex.app/Contents/Resources:${process.env.PATH ?? ''}` };

const tokenize = (s) => {
  const out = []; let cur = ''; let q = null;
  for (let i = 0; i < s.length; i += 1) {
    const c = s[i];
    if (q !== null) { if (c === q) q = null; else cur += c; }
    else if (c === '"' || c === "'") q = c;
    else if (c === ' ' || c === '\t') { if (cur) { out.push(cur); cur = ''; } }
    else cur += c;
  }
  if (cur) out.push(cur);
  return out;
};

const runFugue = (cmd) =>
  new Promise((resolve) => {
    const tokens = tokenize(cmd);
    const args = tokens[0] === 'fuguectl' ? tokens.slice(1) : tokens;
    console.log('[fugue]', FUGUE, args.join(' '));
    execFile(FUGUE, args, { cwd: ROOT, env: ENV, timeout: 300000 }, (err, stdout, stderr) => {
      resolve({ stdout: stdout + stderr, exitCode: err ? (err.code ?? 1) : 0 });
    });
  });

let win = null;
const createWindow = () => {
  win = new BrowserWindow({
    width: 1100,
    height: 760,
    title: 'FuguNano',
    backgroundColor: '#000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  const dev = process.env.VITE_DEV === '1';
  if (dev) win.loadURL('http://localhost:5180');
  else win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
};

ipcMain.handle('fugue:run', (_e, cmd) => runFugue(cmd));
ipcMain.handle('fugue:agents', () => [
  { name: 'codex (gpt-5.5)', role: 'Implementer / Reviewer', healthy: true },
]);

app.whenReady().then(createWindow);
app.on('window-all-closed', () => process.platform !== 'darwin' && app.quit());
app.on('activate', () => win === null && app.isReady() && createWindow());
