/**
 * Configuration System Usage Examples
 * Demonstrates how to use the environment detection and configuration management system
 */

import { 
  getConfigurationManager, 
  getEnvironmentDetector, 
  createConfigurationAdapter,
  DeploymentEnvironment,
  ConfigurationAdapterFactory
} from './index';

/**
 * Example 1: Basic configuration usage
 */
export function basicConfigurationUsage() {
  // Get the configuration manager instance
  const configManager = getConfigurationManager();
  
  // Get the current configuration
  const config = configManager.getConfiguration();
  
  console.log('Current configuration:', {
    environment: config.environment,
    deploymentMode: config.deploymentMode,
    connectionTimeout: config.connectionTimeout,
    maxConnections: config.maxConnections
  });
  
  // Check environment type
  if (configManager.isAWSEnvironment()) {
    const awsConfig = configManager.getAWSConfiguration();
    console.log('AWS Configuration:', {
      dynamoDbTableName: awsConfig.dynamoDbTableName,
      region: awsConfig.region
    });
  } else if (configManager.isKubernetesEnvironment()) {
    const k8sConfig = configManager.getKubernetesConfiguration();
    console.log('Kubernetes Configuration:', {
      redisUrl: k8sConfig.redisUrl,
      serviceName: k8sConfig.serviceName,
      port: k8sConfig.port
    });
  }
}

/**
 * Example 2: Using configuration adapters
 */
export function configurationAdapterUsage() {
  // Create an adapter for the current environment
  const adapter = createConfigurationAdapter();
  
  // Get different configuration aspects
  const connectionConfig = adapter.getConnectionConfig();
  const storageConfig = adapter.getStorageConfig();
  const serverConfig = adapter.getServerConfig();
  const healthCheckConfig = adapter.getHealthCheckConfig();
  
  console.log('Adapter configurations:', {
    connection: connectionConfig,
    storage: storageConfig,
    server: serverConfig,
    healthCheck: healthCheckConfig
  });
  
  // Use storage configuration in your application
  if (storageConfig.type === 'dynamodb') {
    console.log(`Using DynamoDB table: ${storageConfig.tableName}`);
  } else if (storageConfig.type === 'redis') {
    console.log(`Using Redis at: ${storageConfig.connectionString}`);
  }
}

/**
 * Example 3: Environment-specific adapter creation
 */
export function environmentSpecificAdapters() {
  const configManager = getConfigurationManager();
  
  try {
    if (configManager.isAWSEnvironment()) {
      // Create AWS-specific adapter
      const awsAdapter = ConfigurationAdapterFactory.createAWSAdapter();
      const storageConfig = awsAdapter.getStorageConfig();
      
      console.log('AWS Storage Config:', storageConfig);
      
      // Use AWS-specific configuration
      if (storageConfig.type === 'dynamodb') {
        // Initialize DynamoDB client with configuration
        console.log(`Initializing DynamoDB with table: ${storageConfig.tableName}`);
      }
    }
    
    if (configManager.isKubernetesEnvironment()) {
      // Create Kubernetes-specific adapter
      const k8sAdapter = ConfigurationAdapterFactory.createKubernetesAdapter();
      const serverConfig = k8sAdapter.getServerConfig();
      
      console.log('Kubernetes Server Config:', serverConfig);
      
      // Use Kubernetes-specific configuration
      if (serverConfig.port) {
        console.log(`Starting server on port: ${serverConfig.port}`);
      }
    }
  } catch (error) {
    console.error('Error creating environment-specific adapter:', error);
  }
}

/**
 * Example 4: Environment detection details
 */
export function environmentDetectionExample() {
  const envDetector = getEnvironmentDetector();
  const envInfo = envDetector.detectEnvironment();
  
  console.log('Environment Detection Results:', {
    environment: envInfo.environment,
    isAWS: envInfo.isAWS,
    isKubernetes: envInfo.isKubernetes,
    region: envInfo.region,
    namespace: envInfo.namespace
  });
  
  // Make decisions based on environment
  switch (envInfo.environment) {
    case DeploymentEnvironment.AWS:
      console.log('Running in AWS Lambda environment');
      console.log(`AWS Region: ${envInfo.region}`);
      break;
      
    case DeploymentEnvironment.KUBERNETES:
      console.log('Running in Kubernetes environment');
      console.log(`Kubernetes Namespace: ${envInfo.namespace}`);
      break;
      
    case DeploymentEnvironment.UNKNOWN:
      console.log('Unknown environment, using default configuration');
      break;
  }
}

/**
 * Example 5: Configuration validation
 */
export function configurationValidationExample() {
  const configManager = getConfigurationManager();
  
  // Validate current configuration
  const validation = configManager.validateConfiguration();
  
  if (validation.isValid) {
    console.log('Configuration is valid');
  } else {
    console.error('Configuration validation failed:');
    validation.errors.forEach(error => {
      console.error(`- ${error}`);
    });
  }
  
  // You can also validate adapter configurations
  const adapter = createConfigurationAdapter();
  const connectionConfig = adapter.getConnectionConfig();
  
  // Custom validation logic
  if (connectionConfig.timeout <= 0) {
    console.error('Invalid connection timeout');
  }
  
  if (connectionConfig.maxConnections <= 0) {
    console.error('Invalid max connections');
  }
}

/**
 * Example 6: Using configuration in a real application component
 */
export class DatabaseConnection {
  private config: any;
  
  constructor() {
    const adapter = createConfigurationAdapter();
    this.config = adapter.getStorageConfig();
  }
  
  async connect() {
    if (this.config.type === 'dynamodb') {
      console.log(`Connecting to DynamoDB table: ${this.config.tableName}`);
      // Initialize AWS DynamoDB client
      // const dynamodb = new AWS.DynamoDB.DocumentClient();
      // return dynamodb;
    } else if (this.config.type === 'redis') {
      console.log(`Connecting to Redis at: ${this.config.connectionString}`);
      // Initialize Redis client
      // const redis = new Redis(this.config.connectionString, {
      //   password: this.config.password
      // });
      // return redis;
    }
  }
  
  getTTL(): number {
    return this.config.ttl;
  }
}

/**
 * Example 7: Server initialization based on environment
 */
export class ServerInitializer {
  private adapter = createConfigurationAdapter();
  
  async initializeServer() {
    const serverConfig = this.adapter.getServerConfig();
    const healthCheckConfig = this.adapter.getHealthCheckConfig();
    
    if (serverConfig.port) {
      console.log(`Starting HTTP server on port ${serverConfig.port}`);
      // Start HTTP server for Kubernetes environment
      // const server = express();
      // server.listen(serverConfig.port, serverConfig.host);
    }
    
    if (healthCheckConfig.enabled) {
      console.log(`Enabling health checks on ${healthCheckConfig.endpoint}`);
      // Set up health check endpoint
      // server.get(healthCheckConfig.endpoint, (req, res) => {
      //   res.json({ status: 'healthy' });
      // });
    }
  }
}

// Export all examples for easy testing
export const examples = {
  basicConfigurationUsage,
  configurationAdapterUsage,
  environmentSpecificAdapters,
  environmentDetectionExample,
  configurationValidationExample,
  DatabaseConnection,
  ServerInitializer
};