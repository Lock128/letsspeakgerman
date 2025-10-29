/**
 * Test script for dual deployment configuration
 * This can be used to verify the configuration system works correctly
 */

import { getFrontendConfigurationManager, getFrontendEnvironmentDetector, WebSocketAdapter } from './index';

// Test environment detection
console.log('=== Environment Detection Test ===');
const envDetector = getFrontendEnvironmentDetector();
const envInfo = envDetector.detectEnvironment();
console.log('Detected environment:', envInfo);

// Test configuration loading
console.log('\n=== Configuration Loading Test ===');
const configManager = getFrontendConfigurationManager();

try {
  const userConfig = configManager.getConfiguration('user');
  console.log('User configuration:', userConfig);
  
  const adminConfig = configManager.getConfiguration('admin');
  console.log('Admin configuration:', adminConfig);
  
  // Test configuration validation
  const userValidation = configManager.validateConfiguration(userConfig);
  console.log('User config validation:', userValidation);
  
  const adminValidation = configManager.validateConfiguration(adminConfig);
  console.log('Admin config validation:', adminValidation);
  
} catch (error) {
  console.error('Configuration loading failed:', error);
}

// Test WebSocket adapter
console.log('\n=== WebSocket Adapter Test ===');
try {
  const testUrl = 'ws://localhost:8080';
  const testOptions = {
    connectionType: 'user' as const,
    deploymentMode: 'kubernetes',
    enableLogging: true
  };
  
  const wsUrl = WebSocketAdapter.buildWebSocketUrl(testUrl, testOptions);
  console.log('Built WebSocket URL:', wsUrl);
  
  const validation = WebSocketAdapter.validateWebSocketUrl(wsUrl);
  console.log('WebSocket URL validation:', validation);
  
  const timeout = WebSocketAdapter.getConnectionTimeout('kubernetes');
  console.log('Connection timeout for Kubernetes:', timeout);
  
  const reconnectInterval = WebSocketAdapter.getReconnectInterval('kubernetes', 1);
  console.log('Reconnect interval for Kubernetes (attempt 1):', reconnectInterval);
  
} catch (error) {
  console.error('WebSocket adapter test failed:', error);
}

// Test message building
console.log('\n=== Message Building Test ===');
try {
  const testConfig = {
    deploymentMode: 'kubernetes',
    connectionType: 'user' as const
  };
  
  const message = WebSocketAdapter.buildMessage('sendMessage', {
    content: 'test message'
  }, testConfig);
  
  console.log('Built message for Kubernetes:', message);
  
  const awsConfig = {
    deploymentMode: 'aws',
    connectionType: 'admin' as const
  };
  
  const awsMessage = WebSocketAdapter.buildMessage('identify', {
    type: 'admin'
  }, awsConfig);
  
  console.log('Built message for AWS:', awsMessage);
  
} catch (error) {
  console.error('Message building test failed:', error);
}

console.log('\n=== Test Complete ===');