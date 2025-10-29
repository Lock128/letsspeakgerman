/**
 * Connection Manager Interface
 * Defines the contract for managing WebSocket connections across different environments
 */

export interface ConnectionMetadata {
  connectionId: string;
  connectionType: 'user' | 'admin';
  timestamp: number;
  ttl?: number;
}

export interface ConnectionManager {
  /**
   * Store a connection with its metadata
   */
  storeConnection(connectionId: string, connectionType: 'user' | 'admin', metadata?: Partial<ConnectionMetadata>): Promise<void>;

  /**
   * Remove a connection
   */
  removeConnection(connectionId: string): Promise<void>;

  /**
   * Get all connections of a specific type
   */
  getConnections(connectionType: 'user' | 'admin'): Promise<string[]>;

  /**
   * Get connection metadata
   */
  getConnectionMetadata(connectionId: string): Promise<ConnectionMetadata | null>;

  /**
   * Update connection type
   */
  updateConnectionType(connectionId: string, connectionType: 'user' | 'admin'): Promise<void>;

  /**
   * Check if a connection exists
   */
  connectionExists(connectionId: string): Promise<boolean>;

  /**
   * Clean up expired connections (if applicable)
   */
  cleanupExpiredConnections?(): Promise<void>;
}