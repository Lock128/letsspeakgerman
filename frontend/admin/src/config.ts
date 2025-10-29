console.log('📋 AdminConfig: Config script loaded!');

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
    console.log('📋 AdminConfig: Getting configuration...');
    
    if (this.cachedConfig) {
      console.log('📋 AdminConfig: Using cached configuration:', this.cachedConfig);
      return this.cachedConfig;
    }

    try {
      console.log('📋 AdminConfig: Loading fresh configuration...');
      const configManager = getFrontendConfigurationManager();
      console.log('📋 AdminConfig: Configuration manager obtained');
      
      const frontendConfig = configManager.getConfiguration('admin');
      console.log('📋 AdminConfig: Frontend configuration loaded:', frontendConfig);
      
      this.cachedConfig = this.adaptConfig(frontendConfig);
      console.log('📋 AdminConfig: Configuration adapted:', this.cachedConfig);
      return this.cachedConfig;
    } catch (error) {
      console.error('❌ AdminConfig: Failed to load configuration:', error);
      console.log('🔄 AdminConfig: Using fallback configuration...');
      const fallbackConfig = this.getFallbackConfig();
      console.log('📋 AdminConfig: Fallback configuration:', fallbackConfig);
      return fallbackConfig;
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
    console.log('🔄 AdminConfig: Creating fallback configuration...');
    
    // Provide fallback configuration for when detection fails
    const protocol = typeof window !== 'undefined' && window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = typeof window !== 'undefined' ? window.location.hostname : 'localhost';
    const port = typeof window !== 'undefined' && window.location.port ? window.location.port : '8080';
    
    // For Docker setup, use port 8080 for WebSocket
    const wsPort = port === '80' || port === '443' ? '8080' : port;
    const wsUrl = `${protocol}//${host}:${wsPort}/ws`;
    
    console.log('🔄 AdminConfig: Fallback WebSocket URL:', wsUrl);
    
    return {
      environment: 'development',
      webSocketUrl: wsUrl,
      connectionType: 'admin',
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      connectionTimeout: 30000,
      enableLogging: true,
      logLevel: 'debug',
      deploymentMode: 'development' as any
    };
  }
}

// Export singleton instance
const configManager = ConfigManager.getInstance();
export const config = configManager.getConfig();

// Export config manager for advanced usage
export { configManager };
