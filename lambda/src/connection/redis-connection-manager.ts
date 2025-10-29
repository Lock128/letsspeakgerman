/**
 * Redis Connection Manager
 * Implements connection management using Redis for Kubernetes environments
 */

// Redis client interface for type safety
interface RedisClientType {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  on(event: string, listener: (...args: any[]) => void): void;
  setEx(key: string, seconds: number, value: string): Promise<void>;
  get(key: string): Promise<string | null>;
  del(key: string): Promise<number>;
  sAdd(key: string, ...members: string[]): Promise<number>;
  sRem(key: string, ...members: string[]): Promise<number>;
  sMembers(key: string): Promise<string[]>;
  expire(key: string, seconds: number): Promise<boolean>;
  exists(key: string): Promise<number>;
  ttl(key: string): Promise<number>;
  keys(pattern: string): Promise<string[]>;
}

// Dynamic Redis client creation
function createClient(options: any): RedisClientType {
  try {
    // Try to load Redis dynamically
    const redis = require('redis');
    return redis.createClient(options);
  } catch (error) {
    console.warn('Redis module not available, using mock client');
    // Return a mock client that throws meaningful errors
    const mockError = new Error('Redis client not available. Install redis package for Kubernetes deployment.');
    return {
      connect: async () => { throw mockError; },
      disconnect: async () => { throw mockError; },
      on: () => { throw mockError; },
      setEx: async () => { throw mockError; },
      get: async () => { throw mockError; },
      del: async () => { throw mockError; },
      sAdd: async () => { throw mockError; },
      sRem: async () => { throw mockError; },
      sMembers: async () => { throw mockError; },
      expire: async () => { throw mockError; },
      exists: async () => { throw mockError; },
      ttl: async () => { throw mockError; },
      keys: async () => { throw mockError; }
    } as RedisClientType;
  }
}
import { ConnectionManager, ConnectionMetadata } from './connection-manager-interface';
import { ConfigurationAdapterFactory } from '../config/configuration-adapter';

export class RedisConnectionManager implements ConnectionManager {
  private client: RedisClientType | null = null;
  private connectionString: string;
  private password?: string;
  private ttl: number;
  private isConnected: boolean = false;
  private connectionPromise: Promise<void> | null = null;

  constructor() {
    const adapter = ConfigurationAdapterFactory.createAdapter();
    const storageConfig = adapter.getStorageConfig();
    
    this.connectionString = storageConfig.connectionString || 'redis://redis-service:6379';
    this.password = storageConfig.password;
    this.ttl = storageConfig.ttl;
  }

  private async ensureConnection(): Promise<void> {
    if (this.isConnected && this.client) {
      return;
    }

    if (this.connectionPromise) {
      return this.connectionPromise;
    }

    this.connectionPromise = this.connect();
    return this.connectionPromise;
  }

  private async connect(): Promise<void> {
    try {
      const clientOptions: any = {
        url: this.connectionString,
        socket: {
          connectTimeout: 10000,
          lazyConnect: true,
          reconnectStrategy: (retries: number) => {
            if (retries > 5) {
              console.error('Redis connection failed after 5 retries');
              return false;
            }
            return Math.min(retries * 1000, 5000);
          }
        }
      };

      if (this.password) {
        clientOptions.password = this.password;
      }

      this.client = createClient(clientOptions);

      this.client.on('error', (error: Error) => {
        console.error('Redis client error:', error);
        this.isConnected = false;
      });

      this.client.on('connect', () => {
        console.log('Redis client connected');
        this.isConnected = true;
      });

      this.client.on('disconnect', () => {
        console.log('Redis client disconnected');
        this.isConnected = false;
      });

      await this.client.connect();
      this.isConnected = true;
      this.connectionPromise = null;
      
      console.log('Redis connection established successfully');
    } catch (error) {
      this.connectionPromise = null;
      console.error('Failed to connect to Redis:', error);
      throw new Error(`Failed to connect to Redis: ${error}`);
    }
  }

  async storeConnection(
    connectionId: string, 
    connectionType: 'user' | 'admin', 
    metadata?: Partial<ConnectionMetadata>
  ): Promise<void> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    const timestamp = Date.now();
    const connectionData: ConnectionMetadata = {
      connectionId,
      connectionType,
      timestamp,
      ttl: Math.floor(Date.now() / 1000) + this.ttl,
      ...metadata
    };

    try {
      const key = `connection:${connectionId}`;
      const typeKey = `connections:${connectionType}`;
      
      // Store connection metadata with TTL
      await this.client.setEx(key, this.ttl, JSON.stringify(connectionData));
      
      // Add to type-specific set with TTL
      await this.client.sAdd(typeKey, connectionId);
      await this.client.expire(typeKey, this.ttl);

      console.log(`Connection ${connectionId} stored in Redis with type: ${connectionType}`);
    } catch (error) {
      console.error(`Failed to store connection ${connectionId}:`, error);
      throw new Error(`Failed to store connection: ${error}`);
    }
  }

  async removeConnection(connectionId: string): Promise<void> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      // Get connection metadata to determine type
      const metadata = await this.getConnectionMetadata(connectionId);
      
      const key = `connection:${connectionId}`;
      await this.client.del(key);

      // Remove from type-specific set if we know the type
      if (metadata) {
        const typeKey = `connections:${metadata.connectionType}`;
        await this.client.sRem(typeKey, connectionId);
      } else {
        // Remove from both sets if we don't know the type
        await this.client.sRem('connections:user', connectionId);
        await this.client.sRem('connections:admin', connectionId);
      }

      console.log(`Connection ${connectionId} removed from Redis`);
    } catch (error) {
      console.error(`Failed to remove connection ${connectionId}:`, error);
      throw new Error(`Failed to remove connection: ${error}`);
    }
  }

  async getConnections(connectionType: 'user' | 'admin'): Promise<string[]> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      const typeKey = `connections:${connectionType}`;
      const connections = await this.client.sMembers(typeKey);
      
      // Filter out expired connections
      const validConnections: string[] = [];
      for (const connectionId of connections) {
        if (await this.connectionExists(connectionId)) {
          validConnections.push(connectionId);
        } else {
          // Remove expired connection from set
          await this.client.sRem(typeKey, connectionId);
        }
      }

      return validConnections;
    } catch (error) {
      console.error(`Failed to get connections of type ${connectionType}:`, error);
      throw new Error(`Failed to get connections: ${error}`);
    }
  }

  async getConnectionMetadata(connectionId: string): Promise<ConnectionMetadata | null> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      const key = `connection:${connectionId}`;
      const data = await this.client.get(key);
      
      if (!data) {
        return null;
      }

      return JSON.parse(data) as ConnectionMetadata;
    } catch (error) {
      console.error(`Failed to get metadata for connection ${connectionId}:`, error);
      throw new Error(`Failed to get connection metadata: ${error}`);
    }
  }

  async updateConnectionType(connectionId: string, connectionType: 'user' | 'admin'): Promise<void> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      // Get current metadata
      const currentMetadata = await this.getConnectionMetadata(connectionId);
      
      if (!currentMetadata) {
        throw new Error(`Connection ${connectionId} not found`);
      }

      // Remove from old type set
      const oldTypeKey = `connections:${currentMetadata.connectionType}`;
      await this.client.sRem(oldTypeKey, connectionId);

      // Update metadata
      const updatedMetadata: ConnectionMetadata = {
        ...currentMetadata,
        connectionType
      };

      // Store updated metadata
      const key = `connection:${connectionId}`;
      const remainingTtl = await this.client.ttl(key);
      const ttlToUse = remainingTtl > 0 ? remainingTtl : this.ttl;
      
      await this.client.setEx(key, ttlToUse, JSON.stringify(updatedMetadata));

      // Add to new type set
      const newTypeKey = `connections:${connectionType}`;
      await this.client.sAdd(newTypeKey, connectionId);
      await this.client.expire(newTypeKey, ttlToUse);

      console.log(`Connection ${connectionId} type updated to: ${connectionType}`);
    } catch (error) {
      console.error(`Failed to update connection type for ${connectionId}:`, error);
      throw new Error(`Failed to update connection type: ${error}`);
    }
  }

  async connectionExists(connectionId: string): Promise<boolean> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      const key = `connection:${connectionId}`;
      const exists = await this.client.exists(key);
      return exists === 1;
    } catch (error) {
      console.error(`Failed to check if connection ${connectionId} exists:`, error);
      return false;
    }
  }

  async cleanupExpiredConnections(): Promise<void> {
    await this.ensureConnection();
    
    if (!this.client) {
      throw new Error('Redis client not initialized');
    }

    try {
      // Get all connection keys
      const connectionKeys = await this.client.keys('connection:*');
      let cleanedCount = 0;

      for (const key of connectionKeys) {
        const exists = await this.client.exists(key);
        if (exists === 0) {
          // Extract connection ID from key
          const connectionId = key.replace('connection:', '');
          
          // Remove from type sets
          await this.client.sRem('connections:user', connectionId);
          await this.client.sRem('connections:admin', connectionId);
          
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        console.log(`Cleaned up ${cleanedCount} expired connections from Redis`);
      }
    } catch (error) {
      console.error('Failed to cleanup expired connections:', error);
      throw new Error(`Failed to cleanup expired connections: ${error}`);
    }
  }

  /**
   * Close the Redis connection (useful for cleanup)
   */
  async disconnect(): Promise<void> {
    if (this.client && this.isConnected) {
      try {
        await this.client.disconnect();
        this.isConnected = false;
        console.log('Redis connection closed');
      } catch (error) {
        console.error('Error closing Redis connection:', error);
      }
    }
  }
}