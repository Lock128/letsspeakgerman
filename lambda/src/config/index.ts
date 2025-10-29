/**
 * Configuration System Index
 * Exports all configuration-related classes and interfaces
 */

// Environment Detection
export {
  EnvironmentDetector,
  DeploymentEnvironment,
  EnvironmentInfo
} from './environment-detector';

// Configuration Management
export {
  ConfigurationManager,
  BaseConfiguration,
  AWSConfiguration,
  KubernetesConfiguration,
  ApplicationConfiguration
} from './configuration-manager';

// Configuration Adapters
export {
  ConfigurationAdapter,
  ConnectionConfig,
  StorageConfig,
  ServerConfig,
  HealthCheckConfig,
  AWSConfigurationAdapter,
  KubernetesConfigurationAdapter,
  ConfigurationAdapterFactory
} from './configuration-adapter';

// Re-export for convenience
import { ConfigurationManager } from './configuration-manager';
import { EnvironmentDetector } from './environment-detector';
import { ConfigurationAdapterFactory } from './configuration-adapter';

// Convenience functions for common use cases
export function getConfigurationManager() {
  return ConfigurationManager.getInstance();
}

export function getEnvironmentDetector() {
  return EnvironmentDetector.getInstance();
}

export function createConfigurationAdapter() {
  return ConfigurationAdapterFactory.createAdapter();
}