/**
 * Configuration Adapters
 * Provides environment-specific configuration adapters and interfaces
 */

import { ConfigurationManager, ApplicationConfiguration, AWSConfiguration, KubernetesConfiguration } from './configuration-manager';

export interface ConfigurationAdapter {
  getConnectionConfig(): ConnectionConfig;
  getStorageConfig(): StorageConfig;
  getServerConfig(): ServerConfig;
  getHealthCheckConfig(): HealthCheckConfig;
}

export interface ConnectionConfig {
  timeout: number;
  maxConnections: number;
  retryAttempts: number;
  retryDelay: number;
}

export interface StorageConfig {
  type: 'dynamodb' | 'redis';
  connectionString?: string;
  tableName?: string;
  password?: string;
  ttl: number;
}

export interface ServerConfig {
  port?: number;
  healthCheckPort?: number;
  host?: string;
  cors?: {
    origin: string[];
    credentials: boolean;
  };
}

export interface HealthCheckConfig {
  enabled: boolean;
  interval: number;
  timeout: number;
  endpoint: string;
}

export class AWSConfigurationAdapter implements ConfigurationAdapter {
  constructor(private config: AWSConfiguration) {}

  getConnectionConfig(): ConnectionConfig {
    return {
      timeout: this.config.connectionTimeout,
      maxConnections: this.config.maxConnections,
      retryAttempts: 3,
      retryDelay: 1000
    };
  }

  getStorageConfig(): StorageConfig {
    return {
      type: 'dynamodb',
      tableName: this.config.dynamoDbTableName,
      ttl: 24 * 60 * 60 // 24 hours in seconds
    };
  }

  getServerConfig(): ServerConfig {
    return {
      cors: {
        origin: ['*'], // API Gateway handles CORS
        credentials: false
      }
    };
  }

  getHealthCheckConfig(): HealthCheckConfig {
    return {
      enabled: false, // AWS Lambda doesn't need health checks
      interval: this.config.healthCheckInterval,
      timeout: 5000,
      endpoint: '/health'
    };
  }
}

export class KubernetesConfigurationAdapter implements ConfigurationAdapter {
  constructor(private config: KubernetesConfiguration) {}

  getConnectionConfig(): ConnectionConfig {
    return {
      timeout: this.config.connectionTimeout,
      maxConnections: this.config.maxConnections,
      retryAttempts: 5,
      retryDelay: 2000
    };
  }

  getStorageConfig(): StorageConfig {
    return {
      type: 'redis',
      connectionString: this.config.redisUrl,
      password: this.config.redisPassword,
      ttl: 24 * 60 * 60 // 24 hours in seconds
    };
  }

  getServerConfig(): ServerConfig {
    return {
      port: this.config.port,
      healthCheckPort: this.config.healthCheckPort,
      host: '0.0.0.0',
      cors: {
        origin: ['*'], // Configure based on ingress
        credentials: true
      }
    };
  }

  getHealthCheckConfig(): HealthCheckConfig {
    return {
      enabled: true,
      interval: this.config.healthCheckInterval,
      timeout: 5000,
      endpoint: '/health'
    };
  }
}

export class ConfigurationAdapterFactory {
  private static configManager = ConfigurationManager.getInstance();

  public static createAdapter(): ConfigurationAdapter {
    const config = this.configManager.getConfiguration();

    if (this.configManager.isAWSEnvironment()) {
      return new AWSConfigurationAdapter(config as AWSConfiguration);
    } else if (this.configManager.isKubernetesEnvironment()) {
      return new KubernetesConfigurationAdapter(config as KubernetesConfiguration);
    } else {
      // Default to AWS adapter for unknown environments
      return new AWSConfigurationAdapter(config as AWSConfiguration);
    }
  }

  public static createAWSAdapter(): AWSConfigurationAdapter {
    const config = this.configManager.getAWSConfiguration();
    return new AWSConfigurationAdapter(config);
  }

  public static createKubernetesAdapter(): KubernetesConfigurationAdapter {
    const config = this.configManager.getKubernetesConfiguration();
    return new KubernetesConfigurationAdapter(config);
  }
}