/**
 * Connection Manager Factory
 * Creates appropriate connection manager instances based on deployment environment
 */

import { ConnectionManager } from './connection-manager-interface';
import { DynamoDBConnectionManager } from './dynamodb-connection-manager';
import { RedisConnectionManager } from './redis-connection-manager';
import { ConfigurationManager } from '../config/configuration-manager';
import { ConfigurationAdapterFactory } from '../config/configuration-adapter';

export class ConnectionManagerFactory {
  private static instance: ConnectionManager | null = null;
  private static configManager = ConfigurationManager.getInstance();

  /**
   * Create a connection manager instance based on the current environment
   */
  public static createConnectionManager(): ConnectionManager {
    if (this.instance) {
      return this.instance;
    }

    const adapter = ConfigurationAdapterFactory.createAdapter();
    const storageConfig = adapter.getStorageConfig();

    if (this.configManager.isAWSEnvironment() || storageConfig.type === 'dynamodb') {
      this.instance = new DynamoDBConnectionManager();
    } else if (this.configManager.isKubernetesEnvironment() || storageConfig.type === 'redis') {
      this.instance = new RedisConnectionManager();
    } else {
      // Default to DynamoDB for unknown environments
      console.warn('Unknown environment detected, defaulting to DynamoDB connection manager');
      this.instance = new DynamoDBConnectionManager();
    }

    return this.instance;
  }

  /**
   * Create a DynamoDB connection manager (for AWS environments)
   */
  public static createDynamoDBConnectionManager(): DynamoDBConnectionManager {
    return new DynamoDBConnectionManager();
  }

  /**
   * Create a Redis connection manager (for Kubernetes environments)
   */
  public static createRedisConnectionManager(): RedisConnectionManager {
    return new RedisConnectionManager();
  }

  /**
   * Reset the singleton instance (useful for testing)
   */
  public static resetInstance(): void {
    this.instance = null;
  }

  /**
   * Get the current instance without creating a new one
   */
  public static getInstance(): ConnectionManager | null {
    return this.instance;
  }
}