/**
 * Configuration Management System
 * Provides environment-specific configuration with fallback logic
 */

import { EnvironmentDetector, DeploymentEnvironment, EnvironmentInfo } from './environment-detector';

export interface BaseConfiguration {
  environment: string;
  deploymentMode: DeploymentEnvironment;
  connectionTimeout: number;
  maxConnections: number;
  healthCheckInterval: number;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}

export interface AWSConfiguration extends BaseConfiguration {
  dynamoDbTableName: string;
  apiGatewayEndpoint?: string;
  region: string;
}

export interface KubernetesConfiguration extends BaseConfiguration {
  redisUrl: string;
  redisPassword?: string;
  serviceName: string;
  namespace: string;
  port: number;
  healthCheckPort: number;
}

export type ApplicationConfiguration = AWSConfiguration | KubernetesConfiguration;

export class ConfigurationManager {
  private static instance: ConfigurationManager;
  private environmentDetector: EnvironmentDetector;
  private cachedConfig: ApplicationConfiguration | null = null;

  private constructor() {
    this.environmentDetector = EnvironmentDetector.getInstance();
  }

  public static getInstance(): ConfigurationManager {
    if (!ConfigurationManager.instance) {
      ConfigurationManager.instance = new ConfigurationManager();
    }
    return ConfigurationManager.instance;
  }

  /**
   * Get the current application configuration
   */
  public getConfiguration(): ApplicationConfiguration {
    if (this.cachedConfig) {
      return this.cachedConfig;
    }

    const environmentInfo = this.environmentDetector.detectEnvironment();
    const config = this.loadConfiguration(environmentInfo);
    this.cachedConfig = config;
    return config;
  }

  /**
   * Check if running in AWS environment
   */
  public isAWSEnvironment(): boolean {
    return this.environmentDetector.detectEnvironment().isAWS;
  }

  /**
   * Check if running in Kubernetes environment
   */
  public isKubernetesEnvironment(): boolean {
    return this.environmentDetector.detectEnvironment().isKubernetes;
  }

  /**
   * Get AWS-specific configuration (throws if not in AWS environment)
   */
  public getAWSConfiguration(): AWSConfiguration {
    const config = this.getConfiguration();
    if (!this.isAWSEnvironment()) {
      throw new Error('Not running in AWS environment');
    }
    return config as AWSConfiguration;
  }

  /**
   * Get Kubernetes-specific configuration (throws if not in Kubernetes environment)
   */
  public getKubernetesConfiguration(): KubernetesConfiguration {
    const config = this.getConfiguration();
    if (!this.isKubernetesEnvironment()) {
      throw new Error('Not running in Kubernetes environment');
    }
    return config as KubernetesConfiguration;
  }

  private loadConfiguration(environmentInfo: EnvironmentInfo): ApplicationConfiguration {
    const baseConfig = this.loadBaseConfiguration();

    if (environmentInfo.isAWS) {
      return this.loadAWSConfiguration(baseConfig, environmentInfo);
    } else if (environmentInfo.isKubernetes) {
      return this.loadKubernetesConfiguration(baseConfig, environmentInfo);
    } else {
      // Default to AWS configuration for unknown environments
      console.warn('Unknown environment detected, defaulting to AWS configuration');
      return this.loadAWSConfiguration(baseConfig, environmentInfo);
    }
  }

  private loadBaseConfiguration(): BaseConfiguration {
    return {
      environment: this.getEnvVar('NODE_ENV', 'development'),
      deploymentMode: this.environmentDetector.detectEnvironment().environment,
      connectionTimeout: parseInt(this.getEnvVar('CONNECTION_TIMEOUT', '30000')),
      maxConnections: parseInt(this.getEnvVar('MAX_CONNECTIONS', '1000')),
      healthCheckInterval: parseInt(this.getEnvVar('HEALTH_CHECK_INTERVAL', '30000')),
      logLevel: this.getEnvVar('LOG_LEVEL', 'info') as 'debug' | 'info' | 'warn' | 'error'
    };
  }

  private loadAWSConfiguration(baseConfig: BaseConfiguration, environmentInfo: EnvironmentInfo): AWSConfiguration {
    return {
      ...baseConfig,
      dynamoDbTableName: this.getEnvVar('CONNECTIONS_TABLE_NAME', 'websocket-connections'),
      apiGatewayEndpoint: process.env.WEBSOCKET_API_ENDPOINT,
      region: environmentInfo.region || this.getEnvVar('AWS_REGION', 'us-east-1')
    };
  }

  private loadKubernetesConfiguration(baseConfig: BaseConfiguration, environmentInfo: EnvironmentInfo): KubernetesConfiguration {
    return {
      ...baseConfig,
      redisUrl: this.getEnvVar('REDIS_URL', 'redis://redis-service:6379'),
      redisPassword: process.env.REDIS_PASSWORD,
      serviceName: this.getEnvVar('SERVICE_NAME', 'websocket-service'),
      namespace: environmentInfo.namespace || 'default',
      port: parseInt(this.getEnvVar('PORT', '8080')),
      healthCheckPort: parseInt(this.getEnvVar('HEALTH_CHECK_PORT', '8081'))
    };
  }

  private getEnvVar(name: string, defaultValue: string): string {
    return process.env[name] || defaultValue;
  }

  /**
   * Reset cached configuration (useful for testing)
   */
  public resetCache(): void {
    this.cachedConfig = null;
    this.environmentDetector.resetCache();
  }

  /**
   * Validate configuration based on environment
   */
  public validateConfiguration(): { isValid: boolean; errors: string[] } {
    const config = this.getConfiguration();
    const errors: string[] = [];

    // Validate base configuration
    if (!config.environment) {
      errors.push('Environment is required');
    }

    if (config.connectionTimeout <= 0) {
      errors.push('Connection timeout must be positive');
    }

    if (config.maxConnections <= 0) {
      errors.push('Max connections must be positive');
    }

    // Environment-specific validation
    if (this.isAWSEnvironment()) {
      const awsConfig = config as AWSConfiguration;
      if (!awsConfig.dynamoDbTableName) {
        errors.push('DynamoDB table name is required for AWS environment');
      }
      if (!awsConfig.region) {
        errors.push('AWS region is required for AWS environment');
      }
    } else if (this.isKubernetesEnvironment()) {
      const k8sConfig = config as KubernetesConfiguration;
      if (!k8sConfig.redisUrl) {
        errors.push('Redis URL is required for Kubernetes environment');
      }
      if (!k8sConfig.serviceName) {
        errors.push('Service name is required for Kubernetes environment');
      }
      if (k8sConfig.port <= 0 || k8sConfig.port > 65535) {
        errors.push('Port must be between 1 and 65535');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}