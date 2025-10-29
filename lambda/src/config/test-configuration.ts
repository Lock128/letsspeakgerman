/**
 * Simple test script to verify configuration system functionality
 * This is for manual testing and verification
 */

import { 
  getConfigurationManager, 
  getEnvironmentDetector, 
  createConfigurationAdapter,
  DeploymentEnvironment 
} from './index';

function testConfigurationSystem() {
  console.log('=== Configuration System Test ===');
  
  // Test environment detection
  const envDetector = getEnvironmentDetector();
  const envInfo = envDetector.detectEnvironment();
  
  console.log('Environment Detection:');
  console.log(`- Environment: ${envInfo.environment}`);
  console.log(`- Is AWS: ${envInfo.isAWS}`);
  console.log(`- Is Kubernetes: ${envInfo.isKubernetes}`);
  console.log(`- Region: ${envInfo.region || 'N/A'}`);
  console.log(`- Namespace: ${envInfo.namespace || 'N/A'}`);
  
  // Test configuration management
  const configManager = getConfigurationManager();
  const config = configManager.getConfiguration();
  
  console.log('\nConfiguration:');
  console.log(`- Deployment Mode: ${config.deploymentMode}`);
  console.log(`- Environment: ${config.environment}`);
  console.log(`- Connection Timeout: ${config.connectionTimeout}`);
  console.log(`- Max Connections: ${config.maxConnections}`);
  console.log(`- Log Level: ${config.logLevel}`);
  
  // Test configuration validation
  const validation = configManager.validateConfiguration();
  console.log('\nConfiguration Validation:');
  console.log(`- Is Valid: ${validation.isValid}`);
  if (!validation.isValid) {
    console.log('- Errors:', validation.errors);
  }
  
  // Test configuration adapter
  const adapter = createConfigurationAdapter();
  const connectionConfig = adapter.getConnectionConfig();
  const storageConfig = adapter.getStorageConfig();
  const serverConfig = adapter.getServerConfig();
  const healthCheckConfig = adapter.getHealthCheckConfig();
  
  console.log('\nAdapter Configuration:');
  console.log('- Connection Config:', connectionConfig);
  console.log('- Storage Config:', storageConfig);
  console.log('- Server Config:', serverConfig);
  console.log('- Health Check Config:', healthCheckConfig);
  
  // Test environment-specific configurations
  if (configManager.isAWSEnvironment()) {
    console.log('\nAWS-specific configuration detected');
    try {
      const awsConfig = configManager.getAWSConfiguration();
      console.log(`- DynamoDB Table: ${awsConfig.dynamoDbTableName}`);
      console.log(`- Region: ${awsConfig.region}`);
    } catch (error) {
      console.log('- Error getting AWS config:', error);
    }
  }
  
  if (configManager.isKubernetesEnvironment()) {
    console.log('\nKubernetes-specific configuration detected');
    try {
      const k8sConfig = configManager.getKubernetesConfiguration();
      console.log(`- Redis URL: ${k8sConfig.redisUrl}`);
      console.log(`- Service Name: ${k8sConfig.serviceName}`);
      console.log(`- Port: ${k8sConfig.port}`);
    } catch (error) {
      console.log('- Error getting Kubernetes config:', error);
    }
  }
  
  console.log('\n=== Test Complete ===');
}

// Export for use in other modules
export { testConfigurationSystem };

// Run test if this file is executed directly
if (require.main === module) {
  testConfigurationSystem();
}