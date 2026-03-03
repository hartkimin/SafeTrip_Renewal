/**
 * SafeTrip Local Reverse Proxy
 * ─────────────────────────────
 * 단일 포트(8888)로 들어오는 요청을 URL 경로 기반으로 로컬 서비스에 라우팅합니다.
 * ngrok 단일 HTTP 터널과 함께 사용합니다.
 *
 * 라우팅 규칙:
 *   /identitytoolkit.googleapis.com/*  → :9099 (Firebase Auth Emulator — 로그인/가입)
 *   /securetoken.googleapis.com/*      → :9099 (Firebase Auth Emulator — 토큰 리프레시)
 *   /www.googleapis.com/identitytoolkit/* → :9099 (Firebase Auth Emulator)
 *   /emulator/v1/*                     → :9099 (Auth Admin API)
 *   /v0/*                              → :9199 (Firebase Storage Emulator)
 *   WebSocket upgrade                  → :9000 (Firebase RTDB Emulator)
 *   /*                                 → :3001 (Backend API)
 *
 * 사용법: node scripts/local-proxy.cjs
 */
'use strict';

const http = require('http');
const net  = require('net');

const PROXY_PORT  = 8888;
const BACKEND_PORT = 3001;
const RTDB_PORT    = 9000;
const AUTH_PORT    = 9099;
const STORAGE_PORT = 9199;

const HTTP_ROUTES = [
  { prefix: '/identitytoolkit.googleapis.com', port: AUTH_PORT    },
  { prefix: '/securetoken.googleapis.com',     port: AUTH_PORT    },  // 토큰 리프레시
  { prefix: '/www.googleapis.com/identitytoolkit', port: AUTH_PORT },
  { prefix: '/emulator/v1',                    port: AUTH_PORT    },
  { prefix: '/v0/',                            port: STORAGE_PORT  },
];

function getHttpTargetPort(url) {
  for (const route of HTTP_ROUTES) {
    if ((url || '/').startsWith(route.prefix)) return route.port;
  }
  return BACKEND_PORT;
}

// ── HTTP 요청 프록시 ──────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  const targetPort = getHttpTargetPort(req.url || '/');

  const options = {
    hostname : '127.0.0.1',
    port     : targetPort,
    path     : req.url,
    method   : req.method,
    headers  : { ...req.headers, host: `127.0.0.1:${targetPort}` },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    // CORS 헤더 추가 (ngrok → 앱 연결 시 필요)
    const headers = {
      ...proxyRes.headers,
      'access-control-allow-origin' : '*',
      'access-control-allow-headers': 'Content-Type, Authorization, x-firebase-client',
    };
    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res);
  });

  req.pipe(proxyReq);
  proxyReq.on('error', (err) => {
    console.error(`[Proxy] HTTP error → :${targetPort} | ${err.message}`);
    if (!res.headersSent) {
      res.writeHead(502);
      res.end('Proxy error: ' + err.message);
    }
  });
});

// ── WebSocket 프록시 (Firebase RTDB) ──────────────────────────────────────
server.on('upgrade', (req, socket, head) => {
  console.log(`[Proxy] WebSocket upgrade → :${RTDB_PORT} | ${req.url}`);

  const targetSocket = net.connect(RTDB_PORT, '127.0.0.1', () => {
    // 업그레이드 요청 헤더를 RTDB 에뮬레이터로 전달
    const upgradeHeaders =
      `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n` +
      Object.entries(req.headers)
        .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(', ') : v}`)
        .join('\r\n') +
      '\r\n\r\n';

    targetSocket.write(upgradeHeaders);
    if (head && head.length > 0) targetSocket.write(head);

    // 양방향 파이프
    socket.pipe(targetSocket);
    targetSocket.pipe(socket);
  });

  socket.on('error',    () => targetSocket.destroy());
  targetSocket.on('error', () => socket.destroy());
  socket.on('close',    () => targetSocket.destroy());
  targetSocket.on('close', () => socket.destroy());
});

// ── 서버 시작 ──────────────────────────────────────────────────────────────
server.listen(PROXY_PORT, '0.0.0.0', () => {
  console.log(`[Proxy] SafeTrip Local Proxy listening on :${PROXY_PORT}`);
  console.log('[Proxy] Routes:');
  console.log(`[Proxy]   /identitytoolkit.googleapis.com → :${AUTH_PORT}   (Firebase Auth 로그인)`);
  console.log(`[Proxy]   /securetoken.googleapis.com    → :${AUTH_PORT}   (Firebase Auth 토큰 리프레시)`);
  console.log(`[Proxy]   /v0/                           → :${STORAGE_PORT}  (Firebase Storage)`);
  console.log(`[Proxy]   WebSocket                       → :${RTDB_PORT}   (Firebase RTDB)`);
  console.log(`[Proxy]   /*                              → :${BACKEND_PORT}  (Backend API)`);
});
