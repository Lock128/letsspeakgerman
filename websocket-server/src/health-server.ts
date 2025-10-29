/**
 * Health Check Server
 * Provides health check and monitoring endpoints for Kubernetes probes
 */

import express from 'express';
import { RedisConnectionManager } from './connection/redis-connection-manager';

interface HealthMetrics {
  connectionCount: number;
  redisConnected: boolean;
  uptime: number;
  timestamp: string;
  version: string;
}

interface ReadinessCheck {
  ready: boolean;
  checks: {
    redis: boolean;
    server: boolean;
  };
  timestamp: string;
}

class HealthServer {
  private app: express.Application;
  private port: number;
  private connectionManager: RedisConnectionManager;
  private startTime: number;
  private connectionCount: number = 0;
  private messageCount: number = 0;
  private server: any;

  constructor(connectionManager: RedisConnectionManager) {
    this.app = express();
    this.port = parseInt(process.env.HEALTH_PORT || '8081');
    this.connectionManager = connectionManager;
    this.startTime = Date.now();
    
    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    this.app.use(express.json());
    
    // Add CORS headers
    this.app.use((req, res, next) => {
      res.header('Access-Control-Allow-Origin', '*');
      res.header('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
      next();
    });
  }

  private setupRoutes(): void {
    // Liveness probe endpoint
    this.app.get('/health', async (req, res) => {
      try {
        const metrics = await this.getHealthMetrics();
        res.status(200).json({
          status: 'healthy',
          ...metrics
        });
      } catch (error) {
        console.error('Health check failed:', error);
        res.status(503).json({
          status: 'unhealthy',
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: new Date().toISOString()
        });
      }
    });

    // Readiness probe endpoint
    this.app.get('/ready', async (req, res) => {
      try {
        const readiness = await this.getReadinessCheck();
        
        if (readiness.ready) {
          res.status(200).json(readiness);
        } else {
          res.status(503).json(readiness);
        }
      } catch (error) {
        console.error('Readiness check failed:', error);
        res.status(503).json({
          ready: false,
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: new Date().toISOString()
        });
      }
    });

    // Metrics endpoint for monitoring
    this.app.get('/metrics', async (req, res) => {
      try {
        const metrics = await this.getDetailedMetrics();
        res.status(200).json(metrics);
      } catch (error) {
        console.error('Metrics collection failed:', error);
        res.status(500).json({
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: new Date().toISOString()
        });
      }
    });

    // Basic info endpoint
    this.app.get('/', (req, res) => {
      res.json({
        service: 'WebSocket Health Server',
        version: process.env.npm_package_version || '1.0.0',
        uptime: Date.now() - this.startTime,
        timestamp: new Date().toISOString()
      });
    });
  }

  private async getHealthMetrics(): Promise<HealthMetrics> {
    let redisConnected = false;
    
    try {
      // Test Redis connection by checking if we can get connections
      await this.connectionManager.getConnections('admin');
      redisConnected = true;
    } catch (error) {
      console.warn('Redis health check failed:', error);
      redisConnected = false;
    }

    return {
      connectionCount: this.connectionCount,
      redisConnected,
      uptime: Date.now() - this.startTime,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0'
    };
  }

  private async getReadinessCheck(): Promise<ReadinessCheck> {
    const checks = {
      redis: false,
      server: true // Server is running if we can execute this
    };

    try {
      // Test Redis connection
      await this.connectionManager.getConnections('admin');
      checks.redis = true;
    } catch (error) {
      console.warn('Redis readiness check failed:', error);
      checks.redis = false;
    }

    return {
      ready: checks.redis && checks.server,
      checks,
      timestamp: new Date().toISOString()
    };
  }

  private async getDetailedMetrics(): Promise<any> {
    const baseMetrics = await this.getHealthMetrics();
    
    let userConnections = 0;
    let adminConnections = 0;
    
    try {
      const users = await this.connectionManager.getConnections('user');
      const admins = await this.connectionManager.getConnections('admin');
      userConnections = users.length;
      adminConnections = admins.length;
    } catch (error) {
      console.warn('Failed to get connection counts:', error);
    }

    return {
      ...baseMetrics,
      connections: {
        total: this.connectionCount,
        user: userConnections,
        admin: adminConnections
      },
      messages: {
        total: this.messageCount
      },
      system: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch,
        memory: process.memoryUsage(),
        pid: process.pid
      }
    };
  }

  // Methods to update metrics from the main server
  public updateConnectionCount(count: number): void {
    this.connectionCount = count;
  }

  public incrementMessageCount(): void {
    this.messageCount++;
  }

  public start(): void {
    this.server = this.app.listen(this.port, () => {
      console.log(`Health server listening on port ${this.port}`);
      console.log(`Health endpoints:`);
      console.log(`  - Liveness:  http://localhost:${this.port}/health`);
      console.log(`  - Readiness: http://localhost:${this.port}/ready`);
      console.log(`  - Metrics:   http://localhost:${this.port}/metrics`);
    });
  }

  public stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          console.log('Health server stopped');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}

export { HealthServer };