/**
 * Environment Detection System
 * Detects whether the application is running in AWS Lambda or Kubernetes environment
 */

export enum DeploymentEnvironment {
  AWS = 'aws',
  KUBERNETES = 'kubernetes',
  UNKNOWN = 'unknown'
}

export interface EnvironmentInfo {
  environment: DeploymentEnvironment;
  isAWS: boolean;
  isKubernetes: boolean;
  region?: string;
  namespace?: string;
}

export class EnvironmentDetector {
  private static instance: EnvironmentDetector;
  private cachedEnvironment: EnvironmentInfo | null = null;

  private constructor() {}

  public static getInstance(): EnvironmentDetector {
    if (!EnvironmentDetector.instance) {
      EnvironmentDetector.instance = new EnvironmentDetector();
    }
    return EnvironmentDetector.instance;
  }

  /**
   * Detect the current deployment environment
   */
  public detectEnvironment(): EnvironmentInfo {
    if (this.cachedEnvironment) {
      return this.cachedEnvironment;
    }

    const environment = this.performEnvironmentDetection();
    this.cachedEnvironment = environment;
    return environment;
  }

  private performEnvironmentDetection(): EnvironmentInfo {
    // Check for explicit environment variable first
    const explicitEnv = process.env.DEPLOYMENT_MODE?.toLowerCase();
    if (explicitEnv === 'aws' || explicitEnv === 'kubernetes') {
      return this.createEnvironmentInfo(explicitEnv as DeploymentEnvironment);
    }

    // AWS Lambda detection
    if (this.isAWSEnvironment()) {
      return this.createEnvironmentInfo(DeploymentEnvironment.AWS);
    }

    // Kubernetes detection
    if (this.isKubernetesEnvironment()) {
      return this.createEnvironmentInfo(DeploymentEnvironment.KUBERNETES);
    }

    // Default to unknown
    return this.createEnvironmentInfo(DeploymentEnvironment.UNKNOWN);
  }

  private isAWSEnvironment(): boolean {
    // AWS Lambda specific environment variables
    return !!(
      process.env.AWS_LAMBDA_FUNCTION_NAME ||
      process.env.AWS_EXECUTION_ENV ||
      process.env.LAMBDA_TASK_ROOT ||
      process.env.AWS_REGION
    );
  }

  private isKubernetesEnvironment(): boolean {
    // Kubernetes specific environment variables and file system indicators
    return !!(
      process.env.KUBERNETES_SERVICE_HOST ||
      process.env.KUBERNETES_SERVICE_PORT ||
      this.hasKubernetesServiceAccount()
    );
  }

  private hasKubernetesServiceAccount(): boolean {
    try {
      const fs = require('fs');
      return fs.existsSync('/var/run/secrets/kubernetes.io/serviceaccount/token');
    } catch {
      return false;
    }
  }

  private createEnvironmentInfo(environment: DeploymentEnvironment): EnvironmentInfo {
    const info: EnvironmentInfo = {
      environment,
      isAWS: environment === DeploymentEnvironment.AWS,
      isKubernetes: environment === DeploymentEnvironment.KUBERNETES
    };

    // Add AWS-specific information
    if (info.isAWS) {
      info.region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION;
    }

    // Add Kubernetes-specific information
    if (info.isKubernetes) {
      info.namespace = process.env.KUBERNETES_NAMESPACE || 'default';
    }

    return info;
  }

  /**
   * Reset cached environment (useful for testing)
   */
  public resetCache(): void {
    this.cachedEnvironment = null;
  }
}