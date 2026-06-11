import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import config from './config/environment';
import logger from './config/logger';
import { initializeRedis, closeRedis } from './config/redis';
import { initializeQueue, closeQueue } from './config/queue';
import { registerMessageQueueProcessor } from './workers/messageQueueWorker';
import { requestIdMiddleware } from './middleware/requestId';
import { errorHandler, asyncHandler } from './middleware/errorHandler';
import { globalRateLimiter } from './middleware/rateLimiter';
import authRoutes from './routes/auth';
import botsRoutes from './routes/bots';
import botTemplatesRoutes from './routes/botTemplates';
import subscriptionsRoutes from './routes/subscriptions';
import paymentsRoutes from './routes/payments';
import invoicesRoutes from './routes/invoices';
import webhooksRoutes from './routes/webhooks';

const app: Express = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true,
  },
  xContentTypeOptions: true,
  xFrameOptions: { action: 'deny' },
  xXssProtection: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));

// CORS middleware
app.use(cors({
  origin: config.allowedOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  exposedHeaders: ['X-Request-ID', 'X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-RateLimit-Reset'],
  maxAge: 86400,
}));

// Request ID middleware (before body parsing for webhook routes)
app.use(requestIdMiddleware);

// Webhook routes (must be before express.json() to capture raw body)
app.use('/api/webhooks', webhooksRoutes);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Global rate limiter
app.use(globalRateLimiter);

// Health check endpoint
app.get('/health', asyncHandler(async (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: config.nodeEnv,
  });
}));

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/bots', botsRoutes);
app.use('/api/templates', botTemplatesRoutes);
app.use('/api/subscriptions', subscriptionsRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/invoices', invoicesRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    errorCode: 'NOT_FOUND',
    path: req.path,
    method: req.method,
  });
});

// Global error handler (must be last)
app.use(errorHandler);

// Initialize server
const startServer = async () => {
  try {
    logger.info('Starting server initialization...');

    // Initialize Redis
    await initializeRedis();
    logger.info('Redis initialized successfully');

    // Initialize message queue
    await initializeQueue();
    logger.info('Message queue initialized successfully');

    // Register message queue processor
    await registerMessageQueueProcessor(5); // Process 5 messages in parallel
    logger.info('Message queue processor registered successfully');

    // Start server
    const PORT = config.port;
    app.listen(PORT, () => {
      logger.info(`Server running on port ${PORT} in ${config.nodeEnv} mode`);
      logger.info(`API available at http://localhost:${PORT}`);
    });
  } catch (error: any) {
    logger.error(`Failed to start server: ${error.message}`);
    logger.error(`Stack: ${error.stack}`);
    console.error('FULL ERROR:', error);
    process.exit(1);
  }
};

// Handle graceful shutdown
const gracefulShutdown = async () => {
  logger.info('Shutting down gracefully...');
  try {
    await closeQueue();
    await closeRedis();
    logger.info('All connections closed');
    process.exit(0);
  } catch (error: any) {
    logger.error(`Error during shutdown: ${error.message}`);
    process.exit(1);
  }
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Start the server
startServer();

export default app;
