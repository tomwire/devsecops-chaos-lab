'use strict';

const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'production';

// --------------------------------------------------------------------------
// Health / Readiness Endpoints
// --------------------------------------------------------------------------

/** @swagger
 * /healthz:
 *   get:
 *     summary: Liveness probe — "am I still alive?"
 *     responses:
 *       200: description=Application is running
 */
app.get('/healthz', (_req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

/** @swagger
 * /readyz:
 *   get:
 *     summary: Readiness probe — "am I ready to serve traffic?"
 *     responses:
 *       200: description=Application is ready
 */
app.get('/readyz', (_req, res) => {
  // In a real app we'd check DB connections, cache status, etc.
  res.status(200).json({ ready: true });
});

/** @swagger
 * /version:
 *   get:
 *     summary: Returns the running version for canary tracking
 *     responses:
 *       200: description=Version information
 */
app.get('/version', (_req, res) => {
  const pkg = require('./package.json');
  res.json({
    name: pkg.name,
    version: pkg.version,
    environment: NODE_ENV,
    host: process.env.HOSTNAME || 'unknown',
  });
});

/** @swagger
 * /metrics:
 *   get:
 *     summary: Basic Prometheus-style metrics (lightweight)
 *     responses:
 *       200: description=Metrics in text exposition format
 */
app.get('/metrics', (_req, res) => {
  const lines = [
    `sample_app_uptime_seconds ${process.uptime()}`,
    `sample_app_node_version ${process.version}`,
    `sample_app_memory_heap_used_bytes ${process.memoryUsage().heapUsed}`,
    `sample_app_gc_collections_total ${process.memoryUsage().external || 0}`,
  ];
  res.type('text/plain; charset=utf-8').send(lines.join('\n') + '\n');
});

// --------------------------------------------------------------------------
// Graceful Shutdown
// --------------------------------------------------------------------------

function shutdown(signal) {
  console.log(`[shutdown] Received ${signal}, draining connections...`);
  app.close(() => {
    process.exit(0);
  });
  // Hard timeout in case connections don't drain
  setTimeout(() => {
    console.error('[shutdown] Force exit after timeout');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// --------------------------------------------------------------------------
// Start Server
// --------------------------------------------------------------------------

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[sample-app] Listening on :${PORT} (env=${NODE_ENV})`);
});

module.exports = { app, server };
