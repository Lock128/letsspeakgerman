/**
 * WebSocket Adapter for Dual Deployment Mode
 * Handles environment-specific WebSocket connection logic
 */

import { DeploymentEnvironment } from './environment-detector.js';

export interface WebSocketConnectionOptions {
  connectionType: 'user' | 'admin';
  deploymentMode: string;
  enableLogging?: boolean;
  connectionTimeout?: number;
}

export class WebSocketAdapter {
  /**
   * Build WebSocket URL with environment-specific parameters
   */
  static buildWebSocketUrl(baseUrl: string, options: WebSocketConnectionOptions): string {
    const url = new URL(baseUrl);
    
    // Add connection type as query parameter for identification
    url.searchParams.set('type', options.connectionType);
    
    // Add deployment mode for server-side routing if needed
    url.searchParams.set('mode', options.deploymentMode);
    
    // Add timestamp to prevent caching issues
    url.searchParams.set('t', Date.now().toString());

    return url.toString();
  }

  /**
   * Create WebSocket connection with environment-specific configuration
   */
  static createConnection(baseUrl: string, options: WebSocketConnectionOptions): WebSocket {
    const wsUrl = this.buildWebSocketUrl(baseUrl, options);
    
    if (options.enableLogging) {
      console.log(`Creating WebSocket connection: ${wsUrl} (${options.deploymentMode} mode)`);
    }

    return new WebSocket(wsUrl);
  }

  /**
   * Build message with environment-specific format
   */
  static buildMessage(action: string, data: any, config: { deploymentMode: string; connectionType: 'user' | 'admin' }): any {
    const baseMessage = {
      ...data,
      timestamp: Date.now(),
      type: config.connectionType
    };

    // Environment-specific message format
    switch (config.deploymentMode) {
      case DeploymentEnvironment.AWS:
      case 'aws':
        // AWS API Gateway format
        return {
          action,
          data: baseMessage
        };
      case DeploymentEnvironment.KUBERNETES:
      case DeploymentEnvironment.DEVELOPMENT:
      case 'kubernetes':
      case 'development':
      default:
        // Direct WebSocket format
        return {
          action,
          ...baseMessage
        };
    }
  }

  /**
   * Get environment-specific error message
   */
  static getErrorMessage(deploymentMode: string, errorType: 'connection' | 'send' | 'timeout'): string {
    const messages = {
      kubernetes: {
        connection: 'Failed to connect to messaging system. Please check if the service is running.',
        send: 'Failed to send message. Please check the connection.',
        timeout: 'Connection timeout. Please try again.'
      },
      aws: {
        connection: 'Failed to connect to AWS WebSocket API. Please check your connection.',
        send: 'Failed to send message to AWS API Gateway.',
        timeout: 'AWS API Gateway timeout. Please try again.'
      },
      development: {
        connection: 'Failed to connect to development server. Please ensure the WebSocket server is running.',
        send: 'Failed to send message to development server.',
        timeout: 'Development server timeout. Please check if the server is running.'
      }
    };

    return messages[deploymentMode as keyof typeof messages]?.[errorType] || 
           `Failed to ${errorType === 'connection' ? 'connect to' : errorType} messaging system`;
  }

  /**
   * Validate WebSocket URL format
   */
  static validateWebSocketUrl(url: string): { isValid: boolean; error?: string } {
    try {
      const parsedUrl = new URL(url);
      
      if (!['ws:', 'wss:'].includes(parsedUrl.protocol)) {
        return { isValid: false, error: 'Invalid WebSocket protocol. Must be ws: or wss:' };
      }

      if (!parsedUrl.hostname) {
        return { isValid: false, error: 'Invalid hostname in WebSocket URL' };
      }

      return { isValid: true };
    } catch (error) {
      return { isValid: false, error: 'Invalid WebSocket URL format' };
    }
  }

  /**
   * Get connection timeout based on deployment mode
   */
  static getConnectionTimeout(deploymentMode: string): number {
    const timeouts = {
      kubernetes: 30000,  // 30 seconds for K8s
      aws: 45000,         // 45 seconds for AWS (higher latency)
      development: 10000  // 10 seconds for local dev
    };

    return timeouts[deploymentMode as keyof typeof timeouts] || 30000;
  }

  /**
   * Get reconnect interval based on deployment mode
   */
  static getReconnectInterval(deploymentMode: string, attempt: number): number {
    const baseIntervals = {
      kubernetes: 2000,   // 2 seconds base for K8s
      aws: 5000,          // 5 seconds base for AWS
      development: 1000   // 1 second base for local dev
    };

    const baseInterval = baseIntervals[deploymentMode as keyof typeof baseIntervals] || 2000;
    
    // Exponential backoff with jitter
    const exponentialDelay = Math.min(baseInterval * Math.pow(1.5, attempt - 1), 30000);
    const jitter = Math.random() * 1000; // Add up to 1 second of jitter
    
    return exponentialDelay + jitter;
  }
}