import { createApp } from './app.js';
import { env } from './config/env.js';
import { initStorage } from './services/storage-service.js';

async function main() {
  await initStorage();

  const app = createApp();

  const server = app.listen(env.API_PORT, () => {
    console.info(`🚀 GifStudio API running on http://${env.API_HOST}:${env.API_PORT}`);
    console.info(`📋 Environment: ${env.NODE_ENV}`);
    console.info(`🏥 Health check: http://${env.API_HOST}:${env.API_PORT}/api/v1/health`);
  });

  const gracefulShutdown = (signal: string): void => {
    console.info(`\n${signal} received, shutting down gracefully...`);
    server.close(() => {
      console.info('Server closed.');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

main().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
