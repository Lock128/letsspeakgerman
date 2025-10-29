/**
 * Connection Management Module
 * Exports all connection-related interfaces and implementations
 */

// Interfaces
export {
  ConnectionManager,
  ConnectionMetadata
} from './connection-manager-interface';

// Implementations
export { DynamoDBConnectionManager } from './dynamodb-connection-manager';
export { RedisConnectionManager } from './redis-connection-manager';

// Factory
export { ConnectionManagerFactory } from './connection-manager-factory';

// Convenience function
import { ConnectionManagerFactory } from './connection-manager-factory';

export function createConnectionManager() {
  return ConnectionManagerFactory.createConnectionManager();
}