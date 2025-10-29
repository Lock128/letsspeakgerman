/**
 * Frontend Configuration System Index
 * Exports all frontend configuration-related classes and interfaces
 */

// Environment Detection
export {
  FrontendEnvironmentDetector,
  DeploymentEnvironment
} from './environment-detector';

export type { FrontendEnvironmentInfo } from './environment-detector';

// Configuration Management
export { FrontendConfigurationManager } from './configuration-manager';

export type {
  BaseFrontendConfiguration,
  AWSFrontendConfiguration,
  KubernetesFrontendConfiguration,
  DevelopmentFrontendConfiguration,
  FrontendConfiguration
} from './configuration-manager';

// WebSocket Adapter
export { WebSocketAdapter } from './websocket-adapter';
export type { WebSocketConnectionOptions } from './websocket-adapter';

// Re-export for convenience
import { FrontendConfigurationManager } from './configuration-manager';
import { FrontendEnvironmentDetector } from './environment-detector';

// Convenience functions
export function getFrontendConfigurationManager() {
  return FrontendConfigurationManager.getInstance();
}

export function getFrontendEnvironmentDetector() {
  return FrontendEnvironmentDetector.getInstance();
}