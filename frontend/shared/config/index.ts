/**
 * Frontend Configuration System Index
 * Exports all frontend configuration-related classes and interfaces
 */

// Environment Detection
export {
  FrontendEnvironmentDetector,
  DeploymentEnvironment
} from './environment-detector.js';

export type { FrontendEnvironmentInfo } from './environment-detector.js';

// Configuration Management
export { FrontendConfigurationManager } from './configuration-manager.js';

export type {
  BaseFrontendConfiguration,
  AWSFrontendConfiguration,
  KubernetesFrontendConfiguration,
  DevelopmentFrontendConfiguration,
  FrontendConfiguration
} from './configuration-manager.js';

// WebSocket Adapter
export { WebSocketAdapter } from './websocket-adapter.js';
export type { WebSocketConnectionOptions } from './websocket-adapter.js';

// Re-export for convenience
import { FrontendConfigurationManager } from './configuration-manager.js';
import { FrontendEnvironmentDetector } from './environment-detector.js';

// Convenience functions
export function getFrontendConfigurationManager() {
  return FrontendConfigurationManager.getInstance();
}

export function getFrontendEnvironmentDetector() {
  return FrontendEnvironmentDetector.getInstance();
}