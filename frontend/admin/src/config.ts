// Configuration file for admin interface
// Uses environment detection and configuration management system

import { getFrontendConfigurationManager, FrontendConfiguration, DeploymentEnvironment } from '../shared/config/index.js';

export interface Config {
  environment: string;
  webSocketUrl: string;
  connectionType: 'user' | 'admin';
  reconnectInterval: number;
  maxReconnectAttempts: number;
  connectionTimeout: number;
  enableLogging: boolean;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
  deploymentMode: DeploymentEnvironment;
}

class ConfigManager {
  private static instance: ConfigManager;
  private cachedConfig: Config | null = null;

  private constructor() {}

  public static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  public getConfig(): Config {
    if (this.cachedConfig) {
      return this.cachedConfig;
    }

    try {
      const configManager = getFrontendConfigurationManager();
      const frontendConfig = configManager.getConfiguration('admin');
      
      this.cachedConfig = this.adaptConfig(frontendConfig);
      return this.cachedConfig;
    } catch (error) {
      console.error('Failed to load configuration:', error);
      // Return fallback configuration
      return this.getFallbackConfig();
    }
  }

  private adaptConfig(frontendConfig: FrontendConfiguration): Config {
    return {
      environment: frontendConfig.environment,
      webSocketUrl: frontendConfig.webSocketUrl,
      connectionType: frontendConfig.connectionType,
      reconnectInterval: frontendConfig.reconnectInterval,
      maxReconnectAttempts: frontendConfig.maxReconnectAttempts,
      connectionTimeout: frontendConfig.connectionTimeout,
      enableLogging: frontendConfig.enableLogging,
      logLevel: frontendConfig.logLevel,
      deploymentMode: frontendConfig.deploymentMode
    };
  }

  public resetCache(): void {
    this.cachedConfig = null;
  }

  public refreshConfig(): Config {
    this.resetCache();
    return this.getConfig();
  }

  public getWebSocketUrl(): string {
    return this.getConfig().webSocketUrl;
  }

  public isConfigurationValid(): boolean {
    try {
      const config = this.getConfig();
      return !!(config.webSocketUrl && config.connectionType);
    } catch (error) {
      return false;
    }
  }

  private getFallbackConfig(): Config {
    // Provide fallback configuration for when detection fails
    const protocol = typeof window !== 'undefined' && window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = typeof window !== 'undefined' ? window.location.host : 'localhost:8080';
    
    return {
      environment: 'production',
      webSocketUrl: `${protocol}//${host}/ws`,
      connectionType: 'admin',
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      connectionTimeout: 30000,
      enableLogging: true,
      logLevel: 'info',
      deploymentMode: DeploymentEnvironment.KUBERNETES
    };
  }
}

// Export singleton instance
const configManager = ConfigManager.getInstance();
export const config = configManager.getConfig();

// Export config manager for advanced usage
export { configManager };
