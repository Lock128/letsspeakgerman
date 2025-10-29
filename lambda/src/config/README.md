# Environment Detection and Configuration Management System

This system provides automatic environment detection and configuration management for applications that need to run in both AWS Lambda and Kubernetes environments.

## Features

- **Automatic Environment Detection**: Detects whether the application is running in AWS Lambda, Kubernetes, or an unknown environment
- **Environment-Specific Configuration**: Provides different configurations based on the detected environment
- **Configuration Adapters**: Abstracts environment-specific configuration details through adapters
- **Fallback Logic**: Provides sensible defaults when environment variables are not set
- **Validation**: Validates configuration to ensure all required values are present and valid

## Architecture

### Core Components

1. **EnvironmentDetector**: Detects the current deployment environment
2. **ConfigurationManager**: Manages environment-specific configurations
3. **ConfigurationAdapter**: Provides abstracted configuration interfaces
4. **ConfigurationAdapterFactory**: Creates appropriate adapters based on environment

### Environment Detection Logic

The system detects environments in the following order:

1. **Explicit Environment Variable**: `DEPLOYMENT_MODE` (aws|kubernetes)
2. **AWS Lambda Detection**: Checks for AWS Lambda-specific environment variables
3. **Kubernetes Detection**: Checks for Kubernetes-specific environment variables and files
4. **Default**: Falls back to AWS configuration for unknown environments

#### AWS Detection Criteria
- `AWS_LAMBDA_FUNCTION_NAME`
- `AWS_EXECUTION_ENV`
- `LAMBDA_TASK_ROOT`
- `AWS_REGION`

#### Kubernetes Detection Criteria
- `KUBERNETES_SERVICE_HOST`
- `KUBERNETES_SERVICE_PORT`
- Service account token file: `/var/run/secrets/kubernetes.io/serviceaccount/token`

## Usage

### Basic Usage

```typescript
import { getConfigurationManager, createConfigurationAdapter } from './config';

// Get configuration manager
const configManager = getConfigurationManager();
const config = configManager.getConfiguration();

// Create environment-appropriate adapter
const adapter = createConfigurationAdapter();
const storageConfig = adapter.getStorageConfig();
```

### Environment-Specific Configuration

```typescript
import { getConfigurationManager } from './config';

const configManager = getConfigurationManager();

if (configManager.isAWSEnvironment()) {
  const awsConfig = configManager.getAWSConfiguration();
  console.log(`Using DynamoDB table: ${awsConfig.dynamoDbTableName}`);
} else if (configManager.isKubernetesEnvironment()) {
  const k8sConfig = configManager.getKubernetesConfiguration();
  console.log(`Using Redis at: ${k8sConfig.redisUrl}`);
}
```

### Using Configuration Adapters

```typescript
import { createConfigurationAdapter } from './config';

const adapter = createConfigurationAdapter();

// Get different configuration aspects
const connectionConfig = adapter.getConnectionConfig();
const storageConfig = adapter.getStorageConfig();
const serverConfig = adapter.getServerConfig();
const healthCheckConfig = adapter.getHealthCheckConfig();

// Use storage configuration
if (storageConfig.type === 'dynamodb') {
  // Initialize DynamoDB client
} else if (storageConfig.type === 'redis') {
  // Initialize Redis client
}
```

## Configuration Structure

### Base Configuration
- `environment`: Node environment (development, production, etc.)
- `deploymentMode`: Detected deployment environment (aws, kubernetes, unknown)
- `connectionTimeout`: Connection timeout in milliseconds
- `maxConnections`: Maximum number of connections
- `healthCheckInterval`: Health check interval in milliseconds
- `logLevel`: Logging level (debug, info, warn, error)

### AWS Configuration
Extends base configuration with:
- `dynamoDbTableName`: DynamoDB table name for connection storage
- `apiGatewayEndpoint`: API Gateway WebSocket endpoint
- `region`: AWS region

### Kubernetes Configuration
Extends base configuration with:
- `redisUrl`: Redis connection URL
- `redisPassword`: Redis password (optional)
- `serviceName`: Kubernetes service name
- `namespace`: Kubernetes namespace
- `port`: Application port
- `healthCheckPort`: Health check port

## Environment Variables

### Common Variables
- `NODE_ENV`: Node environment (default: development)
- `CONNECTION_TIMEOUT`: Connection timeout in ms (default: 30000)
- `MAX_CONNECTIONS`: Maximum connections (default: 1000)
- `HEALTH_CHECK_INTERVAL`: Health check interval in ms (default: 30000)
- `LOG_LEVEL`: Log level (default: info)

### AWS-Specific Variables
- `CONNECTIONS_TABLE_NAME`: DynamoDB table name (default: websocket-connections)
- `WEBSOCKET_API_ENDPOINT`: API Gateway WebSocket endpoint
- `AWS_REGION`: AWS region (default: us-east-1)

### Kubernetes-Specific Variables
- `REDIS_URL`: Redis connection URL (default: redis://redis-service:6379)
- `REDIS_PASSWORD`: Redis password
- `SERVICE_NAME`: Service name (default: websocket-service)
- `KUBERNETES_NAMESPACE`: Namespace (default: default)
- `PORT`: Application port (default: 8080)
- `HEALTH_CHECK_PORT`: Health check port (default: 8081)

### Override Variables
- `DEPLOYMENT_MODE`: Force specific environment (aws|kubernetes)

## Configuration Adapters

### Connection Configuration
```typescript
interface ConnectionConfig {
  timeout: number;
  maxConnections: number;
  retryAttempts: number;
  retryDelay: number;
}
```

### Storage Configuration
```typescript
interface StorageConfig {
  type: 'dynamodb' | 'redis';
  connectionString?: string;
  tableName?: string;
  password?: string;
  ttl: number;
}
```

### Server Configuration
```typescript
interface ServerConfig {
  port?: number;
  healthCheckPort?: number;
  host?: string;
  cors?: {
    origin: string[];
    credentials: boolean;
  };
}
```

### Health Check Configuration
```typescript
interface HealthCheckConfig {
  enabled: boolean;
  interval: number;
  timeout: number;
  endpoint: string;
}
```

## Validation

The system includes built-in validation for configurations:

```typescript
const configManager = getConfigurationManager();
const validation = configManager.validateConfiguration();

if (!validation.isValid) {
  console.error('Configuration errors:', validation.errors);
}
```

## Testing

Use the test configuration script to verify the system:

```bash
# Test with default environment
node -e "require('./dist/config/test-configuration').testConfigurationSystem()"

# Test with AWS environment
AWS_LAMBDA_FUNCTION_NAME=test node -e "require('./dist/config/test-configuration').testConfigurationSystem()"

# Test with Kubernetes environment
KUBERNETES_SERVICE_HOST=kubernetes.default.svc.cluster.local node -e "require('./dist/config/test-configuration').testConfigurationSystem()"
```

## Examples

See `usage-examples.ts` for comprehensive examples of how to use the configuration system in different scenarios.