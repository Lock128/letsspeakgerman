/**
 * Frontend Configuration Management System
 * Provides environment-specific configuration for frontend applications
 */

import { FrontendEnvironmentDetector, DeploymentEnvironment, FrontendEnvironmentInfo } from './environment-detector.js';

export interface BaseFrontendConfiguration {
  environment: string;
  deploymentMode: DeploymentEnvironment;
  connectionType: 'user' | 'admin';
  reconnectInterval: number;
  maxReconnectAttempts: number;
  connectionTimeout: number;
  enableLogging: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}

export interface AWSFrontendConfiguration extends BaseFrontendConfiguration {
  webSocketUrl: string;
  apiGatewayEndpoint?: string;
  region?: string;
}

export interface KubernetesFrontendConfiguration extends BaseFrontendConfiguration {
  webSocketUrl: string;
  apiEndpoint: string;
  namespace?: string;
  serviceName?: string;
}

export interface DevelopmentFrontendConfiguration extends BaseFrontendConfiguration {
  webSocketUrl: string;
  apiEndpoint?: string;
  mockData?: boolean;
}

export type FrontendConfiguration = 
  | AWSFrontendConfiguration 
  | KubernetesFrontendConfiguration 
  | DevelopmentFrontendConfiguration;

export class FrontendConfigurationManager {
  private static instance: FrontendConfigurationManager;
  private environmentDetector: FrontendEnvironmentDetector;
  private cachedConfig: FrontendConfiguration | null = null;

  private constructor() {
    this.environmentDetector = FrontendEnvironmentDetector.getInstance();
  }

  public static getInstance(): FrontendConfigurationManager {
    if (!FrontendConfigurationManager.instance) {
      FrontendConfigurationManager.instance = new FrontendConfigurationManager();
    }
    return FrontendConfigurationManager.instance;
  }

  /**
   * Get the current frontend configuration
   */
  public getConfiguration(connectionType: 'user' | 'admin'): FrontendConfiguration {
    if (this.cachedConfig && this.cachedConfig.connectionType === connectionType) {
      return this.cachedConfig;
    }

    const environmentInfo = this.environmentDetector.detectEnvironment();
    const config = this.loadConfiguration(environmentInfo, connectionType);
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
   * Check if running in development environment
   */
  public isDevelopmentEnvironment(): boolean {
    return this.environmentDetector.detectEnvironment().isDevelopment;
  }

  private loadConfiguration(environmentInfo: FrontendEnvironmentInfo, connectionType: 'user' | 'admin'): FrontendConfiguration {
    const baseConfig = this.loadBaseConfiguration(connectionType);

    if (environmentInfo.isAWS) {
      return this.loadAWSConfiguration(baseConfig);
    } else if (environmentInfo.isKubernetes) {
      return this.loadKubernetesConfiguration(baseConfig);
    } else if (environmentInfo.isDevelopment) {
      return this.loadDevelopmentConfiguration(baseConfig);
    } else {
      // Default to AWS configuration
      return this.loadAWSConfiguration(baseConfig);
    }
  }

  private loadBaseConfiguration(connectionType: 'user' | 'admin'): BaseFrontendConfiguration {
    return {
      environment: this.getConfigValue('NODE_ENV', 'production'),
      deploymentMode: this.environmentDetector.detectEnvironment().environment,
      connectionType,
      reconnectInterval: parseInt(this.getConfigValue('RECONNECT_INTERVAL', '5000')),
      maxReconnectAttempts: parseInt(this.getConfigValue('MAX_RECONNECT_ATTEMPTS', '10')),
      connectionTimeout: parseInt(this.getConfigValue('CONNECTION_TIMEOUT', '30000')),
      enableLogging: this.getConfigValue('ENABLE_LOGGING', 'true') === 'true',
      logLevel: this.getConfigValue('LOG_LEVEL', 'info') as 'debug' | 'info' | 'warn' | 'error'
    };
  }

  private loadAWSConfiguration(baseConfig: BaseFrontendConfiguration): AWSFrontendConfiguration {
    return {
      ...baseConfig,
      webSocketUrl: this.getConfigValue('WEBSOCKET_URL', 'wss://your-api-gateway-id.execute-api.region.amazonaws.com/prod'),
      apiGatewayEndpoint: this.getConfigValue('API_GATEWAY_ENDPOINT'),
      region: this.getConfigValue('AWS_REGION', 'eu-central-1')
    };
  }

  private loadKubernetesConfiguration(baseConfig: BaseFrontendConfiguration): KubernetesFrontendConfiguration {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    
    // For Kubernetes deployment, WebSocket endpoint is typically at /ws path
    const defaultWebSocketUrl = `${protocol}//${host}/ws`;
    
    return {
      ...baseConfig,
      webSocketUrl: this.getConfigValue('WEBSOCKET_URL', defaultWebSocketUrl),
      apiEndpoint: this.getConfigValue('API_ENDPOINT', `${window.location.protocol}//${host}/api`),
      namespace: this.getConfigValue('KUBERNETES_NAMESPACE', 'default'),
      serviceName: this.getConfigValue('SERVICE_NAME', 'websocket-service')
    };
  }

  private loadDevelopmentConfiguration(baseConfig: BaseFrontendConfiguration): DevelopmentFrontendConfiguration {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    
    // For Docker development, use nginx proxy path
    const defaultWebSocketUrl = `${protocol}//${host}/ws`;
    
    return {
      ...baseConfig,
      webSocketUrl: this.getConfigValue('WEBSOCKET_URL', defaultWebSocketUrl),
      apiEndpoint: this.getConfigValue('API_ENDPOINT', `${window.location.protocol}//${host}/api`),
      mockData: this.getConfigValue('MOCK_DATA', 'false') === 'true'
    };
  }

  private getConfigValue(key: string, defaultValue?: string): string {
    // Check window.APP_CONFIG first (injected by build process)
    if (typeof window !== 'undefined' && (window as any).APP_CONFIG) {
      const value = (window as any).APP_CONFIG[key];
      if (value !== undefined) return value;
    }

    // Check meta tags
    if (typeof document !== 'undefined') {
      const metaTag = document.querySelector(`meta[name="config-${key.toLowerCase()}"]`);
      if (metaTag) {
        const content = metaTag.getAttribute('content');
        if (content) return content;
      }
    }

    // Check environment variables (for development)
    if (typeof process !== 'undefined' && process.env) {
      const envValue = process.env[key];
      if (envValue !== undefined) return envValue;
    }

    // Return default value
    return defaultValue || '';
  }

  /**
   * Reset cached configuration (useful for testing)
   */
  public resetCache(): void {
    this.cachedConfig = null;
    this.environmentDetector.resetCache();
  }

  /**
   * Refresh configuration - useful when environment changes
   */
  public refreshConfiguration(connectionType: 'user' | 'admin'): FrontendConfiguration {
    this.resetCache();
    return this.getConfiguration(connectionType);
  }

  /**
   * Get WebSocket URL with fallback logic
   */
  public getWebSocketUrl(connectionType: 'user' | 'admin'): string {
    const config = this.getConfiguration(connectionType);
    return config.webSocketUrl;
  }

  /**
   * Check if current configuration is valid
   */
  public isConfigurationValid(connectionType: 'user' | 'admin'): boolean {
    try {
      const config = this.getConfiguration(connectionType);
      const validation = this.validateConfiguration(config);
      return validation.isValid;
    } catch (error) {
      console.error('Configuration validation error:', error);
      return false;
    }
  }

  /**
   * Validate configuration
   */
  public validateConfiguration(config: FrontendConfiguration): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!config.webSocketUrl) {
      errors.push('WebSocket URL is required');
    }

    if (config.reconnectInterval <= 0) {
      errors.push('Reconnect interval must be positive');
    }

    if (config.maxReconnectAttempts <= 0) {
      errors.push('Max reconnect attempts must be positive');
    }

    if (config.connectionTimeout <= 0) {
      errors.push('Connection timeout must be positive');
    }

    // Environment-specific validation
    if (config.deploymentMode === DeploymentEnvironment.KUBERNETES) {
      const k8sConfig = config as KubernetesFrontendConfiguration;
      if (!k8sConfig.apiEndpoint) {
        errors.push('API endpoint is required for Kubernetes environment');
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}