/**
 * Standalone WebSocket Server for Kubernetes Deployment
 * Provides WebSocket functionality with Express.js and ws library
 */

import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { RedisConnectionManager } from './connection/redis-connection-manager';
import { HealthServer } from './health-server';
import { v4 as uuidv4 } from 'uuid';

interface MessageData {
  action: string;
  data?: {
    content?: string;
    connectionType?: string;
  };
}

interface ExtendedWebSocket extends WebSocket {
  connectionId?: string;
  connectionType?: 'user' | 'admin';
  isAlive?: boolean;
}

class WebSocketServerApp {
  private app: express.Application;
  private server: any;
  private wss: WebSocketServer;
  private connectionManager: RedisConnectionManager;
  private healthServer: HealthServer;
  private port: number;
  private connections: Map<string, ExtendedWebSocket> = new Map();
  private isShuttingDown: boolean = false;
  private messageCount: number = 0;

  constructor() {
    this.app = express();
    this.server = createServer(this.app);
    this.connectionManager = new RedisConnectionManager();
    this.healthServer = new HealthServer(this.connectionManager);
    this.port = parseInt(process.env.PORT || '8080');
    
    // Initialize WebSocket server
    this.wss = new WebSocketServer({ 
      server: this.server,
      path: '/ws'
    });

    this.setupMiddleware();
    this.setupWebSocketHandlers();
    this.setupGracefulShutdown();
    this.startHeartbeat();
  }

  private setupMiddleware(): void {
    // Basic middleware
    this.app.use(express.json());
    
    // CORS headers for WebSocket
    this.app.use((req, res, next) => {
      res.header('Access-Control-Allow-Origin', '*');
      res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
      next();
    });

    // Basic route for testing
    this.app.get('/', (req, res) => {
      res.json({ 
        message: 'WebSocket Server Running',
        connections: this.connections.size,
        timestamp: new Date().toISOString()
      });
    });
  }

  private setupWebSocketHandlers(): void {
    this.wss.on('connection', (ws: ExtendedWebSocket, request) => {
      // Generate unique connection ID
      const connectionId = uuidv4();
      ws.connectionId = connectionId;
      ws.connectionType = 'user'; // Default to user, will be updated by client
      ws.isAlive = true;

      // Store connection locally
      this.connections.set(connectionId, ws);

      // Update health metrics
      this.healthServer.updateConnectionCount(this.connections.size);

      console.log(`WebSocket connection established: ${connectionId}`);

      // Store connection in Redis
      this.connectionManager.storeConnection(connectionId, 'user')
        .catch(error => {
          console.error(`Failed to store connection ${connectionId}:`, error);
        });

      // Handle incoming messages
      ws.on('message', async (data: Buffer) => {
        try {
          const messageData: MessageData = JSON.parse(data.toString());
          await this.handleMessage(ws, messageData);
        } catch (error) {
          console.error(`Error handling message from ${connectionId}:`, error);
          ws.send(JSON.stringify({
            error: 'Invalid message format',
            timestamp: new Date().toISOString()
          }));
        }
      });

      // Handle connection close
      ws.on('close', async () => {
        console.log(`WebSocket connection closed: ${connectionId}`);
        
        // Remove from local connections
        this.connections.delete(connectionId);

        // Update health metrics
        this.healthServer.updateConnectionCount(this.connections.size);

        // Remove from Redis
        try {
          await this.connectionManager.removeConnection(connectionId);
        } catch (error) {
          console.error(`Failed to remove connection ${connectionId}:`, error);
        }
      });

      // Handle connection errors
      ws.on('error', (error) => {
        console.error(`WebSocket error for ${connectionId}:`, error);
      });

      // Handle pong responses for heartbeat
      ws.on('pong', () => {
        ws.isAlive = true;
      });

      // Send connection confirmation
      ws.send(JSON.stringify({
        type: 'connection',
        connectionId: connectionId,
        message: 'Connected successfully',
        timestamp: new Date().toISOString()
      }));
    });

    this.wss.on('error', (error) => {
      console.error('WebSocket server error:', error);
    });
  }

  private async handleMessage(ws: ExtendedWebSocket, messageData: MessageData): Promise<void> {
    const { connectionId } = ws;
    
    if (!connectionId) {
      console.error('Message received from connection without ID');
      return;
    }

    console.log(`Message received from ${connectionId}:`, messageData);

    // Update message count for metrics
    this.messageCount++;
    this.healthServer.incrementMessageCount();

    try {
      if (messageData.action === 'sendMessage') {
        // Handle message sending (user to admin)
        await this.handleSendMessage(ws, messageData);
      } else if (messageData.action === 'setConnectionType') {
        // Handle connection type setting
        await this.handleSetConnectionType(ws, messageData);
      } else if (messageData.action === 'identify') {
        // Handle admin identification
        await this.handleIdentify(ws, messageData);
      } else if (messageData.action === 'ping') {
        // Handle ping - just respond with pong
        ws.send(JSON.stringify({ action: 'pong', timestamp: new Date().toISOString() }));
      } else {
        // Unknown action
        console.log(`Unknown action from ${connectionId}: ${messageData.action}`);
      }
    } catch (error) {
      console.error(`Error processing message from ${connectionId}:`, error);
      ws.send(JSON.stringify({
        error: 'Internal server error',
        timestamp: new Date().toISOString()
      }));
    }
  }

  private async handleSendMessage(ws: ExtendedWebSocket, messageData: MessageData): Promise<void> {
    const content = messageData.data?.content || (messageData as any).content || '';
    console.log(`Extracting content from message:`, { 
      dataContent: messageData.data?.content, 
      directContent: (messageData as any).content,
      finalContent: content 
    });
    
    const message = {
      messageId: uuidv4(),
      content: content,
      timestamp: new Date().toISOString(),
      from: ws.connectionType || 'user',
      connectionId: ws.connectionId
    };

    console.log(`Prepared message for broadcast:`, message);

    // Get admin connections from Redis
    const adminConnectionIds = await this.connectionManager.getConnections('admin');
    console.log(`Found ${adminConnectionIds.length} admin connections, sending to first available:`, adminConnectionIds);

    let successCount = 0;
    let failureCount = 0;

    // Send message to only the first available admin connection
    for (const adminConnectionId of adminConnectionIds) {
      const adminWs = this.connections.get(adminConnectionId);
      console.log(`Checking admin connection ${adminConnectionId}:`, {
        exists: !!adminWs,
        readyState: adminWs?.readyState,
        isOpen: adminWs?.readyState === WebSocket.OPEN
      });
      
      if (adminWs && adminWs.readyState === WebSocket.OPEN) {
        try {
          const messageJson = JSON.stringify(message);
          console.log(`Sending to admin ${adminConnectionId}:`, messageJson);
          adminWs.send(messageJson);
          successCount++;
          console.log(`✅ Message sent successfully to admin connection: ${adminConnectionId}`);
          break; // Only send to first available admin
        } catch (error) {
          console.error(`❌ Failed to send message to ${adminConnectionId}:`, error);
          failureCount++;
          
          // Remove stale connection and try next admin
          await this.removeStaleConnection(adminConnectionId);
        }
      } else {
        // Connection not found locally or not open, remove from Redis
        console.log(`❌ Removing stale connection from Redis: ${adminConnectionId}`);
        await this.removeStaleConnection(adminConnectionId);
        failureCount++;
      }
    }

    console.log(`Message delivery completed: ${successCount} success, ${failureCount} failures`);

    // Send confirmation back to sender
    ws.send(JSON.stringify({
      type: 'messageStatus',
      message: 'Message broadcast completed',
      successCount,
      failureCount,
      timestamp: new Date().toISOString()
    }));
  }

  private async handleIdentify(ws: ExtendedWebSocket, messageData: any): Promise<void> {
    const connectionType = messageData.type as 'user' | 'admin';
    
    if (!connectionType || (connectionType !== 'user' && connectionType !== 'admin')) {
      ws.send(JSON.stringify({
        error: 'Invalid connection type. Must be "user" or "admin"',
        timestamp: new Date().toISOString()
      }));
      return;
    }

    if (!ws.connectionId) {
      ws.send(JSON.stringify({
        error: 'Connection ID not found',
        timestamp: new Date().toISOString()
      }));
      return;
    }

    try {
      // Update in Redis
      await this.connectionManager.updateConnectionType(ws.connectionId, connectionType);
      
      // Update locally
      ws.connectionType = connectionType;

      console.log(`Connection ${ws.connectionId} identified as: ${connectionType}`);

      ws.send(JSON.stringify({
        type: 'identified',
        connectionType: connectionType,
        message: 'Connection identified successfully',
        timestamp: new Date().toISOString()
      }));
    } catch (error) {
      console.error(`Failed to identify connection ${ws.connectionId}:`, error);
      ws.send(JSON.stringify({
        error: 'Failed to identify connection',
        timestamp: new Date().toISOString()
      }));
    }
  }

  private async handleSetConnectionType(ws: ExtendedWebSocket, messageData: MessageData): Promise<void> {
    const connectionType = messageData.data?.connectionType as 'user' | 'admin';
    
    if (!connectionType || (connectionType !== 'user' && connectionType !== 'admin')) {
      ws.send(JSON.stringify({
        error: 'Invalid connection type. Must be "user" or "admin"',
        timestamp: new Date().toISOString()
      }));
      return;
    }

    if (!ws.connectionId) {
      ws.send(JSON.stringify({
        error: 'Connection ID not found',
        timestamp: new Date().toISOString()
      }));
      return;
    }

    try {
      // Update in Redis
      await this.connectionManager.updateConnectionType(ws.connectionId, connectionType);
      
      // Update locally
      ws.connectionType = connectionType;

      console.log(`Connection ${ws.connectionId} type updated to: ${connectionType}`);

      ws.send(JSON.stringify({
        type: 'connectionTypeUpdated',
        connectionType: connectionType,
        message: 'Connection type updated successfully',
        timestamp: new Date().toISOString()
      }));
    } catch (error) {
      console.error(`Failed to update connection type for ${ws.connectionId}:`, error);
      ws.send(JSON.stringify({
        error: 'Failed to update connection type',
        timestamp: new Date().toISOString()
      }));
    }
  }

  private async removeStaleConnection(connectionId: string): Promise<void> {
    try {
      // Remove from local connections
      this.connections.delete(connectionId);
      
      // Remove from Redis
      await this.connectionManager.removeConnection(connectionId);
      
      console.log(`Removed stale connection: ${connectionId}`);
    } catch (error) {
      console.error(`Failed to remove stale connection ${connectionId}:`, error);
    }
  }

  private startHeartbeat(): void {
    // Ping all connections every 30 seconds
    const interval = setInterval(() => {
      if (this.isShuttingDown) {
        clearInterval(interval);
        return;
      }

      this.wss.clients.forEach((ws: ExtendedWebSocket) => {
        if (ws.isAlive === false) {
          console.log(`Terminating dead connection: ${ws.connectionId}`);
          ws.terminate();
          if (ws.connectionId) {
            this.removeStaleConnection(ws.connectionId);
          }
          return;
        }

        ws.isAlive = false;
        ws.ping();
      });
    }, 30000);
  }

  private setupGracefulShutdown(): void {
    const shutdown = async (signal: string) => {
      console.log(`Received ${signal}, starting graceful shutdown...`);
      this.isShuttingDown = true;

      // Close WebSocket server
      this.wss.close(() => {
        console.log('WebSocket server closed');
      });

      // Close all connections gracefully
      this.connections.forEach((ws, connectionId) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({
            type: 'serverShutdown',
            message: 'Server is shutting down',
            timestamp: new Date().toISOString()
          }));
          ws.close();
        }
      });

      // Stop health server
      try {
        await this.healthServer.stop();
      } catch (error) {
        console.error('Error stopping health server:', error);
      }

      // Disconnect from Redis
      try {
        await this.connectionManager.disconnect();
        console.log('Disconnected from Redis');
      } catch (error) {
        console.error('Error disconnecting from Redis:', error);
      }

      // Close HTTP server
      this.server.close(() => {
        console.log('HTTP server closed');
        process.exit(0);
      });

      // Force exit after 10 seconds
      setTimeout(() => {
        console.log('Force exit after timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }

  public start(): void {
    // Start health server first
    this.healthServer.start();
    
    // Start main WebSocket server
    this.server.listen(this.port, () => {
      console.log(`WebSocket server listening on port ${this.port}`);
      console.log(`WebSocket endpoint: ws://localhost:${this.port}/ws`);
    });
  }
}



// Start the server
if (require.main === module) {
  const server = new WebSocketServerApp();
  server.start();
}

export { WebSocketServerApp };