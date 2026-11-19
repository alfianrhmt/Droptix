'use strict';

const http = require('http');
const net = require('net');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');

const PORT = 8080;
const ROOT_DIR = path.resolve(__dirname, '../..');
const WEB_DIR = path.resolve(ROOT_DIR, 'app/build/web');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
};

const server = http.createServer((req, res) => {
  // Teruskan panggilan API, uploads, dan WebSocket Socket.IO langsung ke backend Express (port 3000)
  if (req.url.startsWith('/api/v1') || req.url.startsWith('/uploads') || req.url.startsWith('/socket.io')) {
    const proxyReq = http.request(
      {
        host: '127.0.0.1',
        port: 3000,
        path: req.url,
        method: req.method,
        headers: {
          ...req.headers,
          host: '127.0.0.1:3000',
        },
      },
      (proxyRes) => {
        res.writeHead(proxyRes.statusCode, {
          ...proxyRes.headers,
          'access-control-allow-origin': '*',
        });
        proxyRes.pipe(res, { end: true });
      }
    );
    proxyReq.on('error', (err) => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: { message: 'Gagal terhubung ke backend: ' + err.message } }));
    });
    req.pipe(proxyReq, { end: true });
    return;
  }

  const cleanUrl = req.url.split('?')[0].split('#')[0];
  let filePath = path.join(WEB_DIR, cleanUrl === '/' ? 'index.html' : cleanUrl);

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(WEB_DIR, 'index.html');
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Gagal memuat file: ' + err.message);
      return;
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
    });
    res.end(content);
  });
});

server.on('upgrade', (req, clientSocket, head) => {
  const serverSocket = net.connect(3000, '127.0.0.1', () => {
    let rawHeaders = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      const key = req.rawHeaders[i];
      let val = req.rawHeaders[i + 1];
      if (key.toLowerCase() === 'host') {
        val = '127.0.0.1:3000';
      }
      rawHeaders += `${key}: ${val}\r\n`;
    }
    rawHeaders += '\r\n';

    serverSocket.write(rawHeaders);
    if (head && head.length > 0) {
      serverSocket.write(head);
    }
    clientSocket.pipe(serverSocket);
    serverSocket.pipe(clientSocket);
  });

  serverSocket.on('error', () => {
    clientSocket.destroy();
  });

  clientSocket.on('error', () => {
    serverSocket.destroy();
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server Droptix Web aktif di port ${PORT}.`);
  console.log(`Ketik [q] lalu tekan Enter kapan saja untuk mematikan backend dan keluar.\n`);

  // Buka Google Chrome / browser default laptop otomatis ke http://localhost:8080
  try {
    const { exec } = require('child_process');
    if (process.platform === 'win32') {
      exec('start "" "http://localhost:8080"');
    }
  } catch (_) {}
});

// Menangani perintah 'q' untuk keluar dan mematikan backend
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

rl.on('line', (line) => {
  const cmd = line.trim().toLowerCase();
  if (cmd === 'q' || cmd === 'quit' || cmd === 'exit') {
    console.log('\nMenghentikan backend dan database Docker...');
    try {
      execSync('docker compose down', { stdio: 'inherit', cwd: ROOT_DIR });
      console.log('[OK] Backend berhasil dihentikan.');
    } catch (err) {
      console.error('Gagal menghentikan docker:', err.message);
    }
    console.log('Sampai jumpa!');
    process.exit(0);
  }
});
