/**
 * Frontend Environment Detection System
 * Detects deployment environment for frontend applications
 */

export enum DeploymentEnvironment {
  AWS = 'aws',
  KUBERNETES = 'kubernetes',
  DEVELOPMENT = 'development'
}

export interface FrontendEnvironmentInfo {
  environment: DeploymentEnvironment;
  isAWS: boolean;
  isKubernetes: boolean;
  isDevelopment: boolean;
}

export class FrontendEnvironmentDetector {
  private static instance: FrontendEnvironmentDetector;
  private cachedEnvironment: FrontendEnvironmentInfo | null = null;

  private constructor() {}

  public static getInstance(): FrontendEnvironmentDetector {
    if (!FrontendEnvironmentDetector.instance) {
      FrontendEnvironmentDetector.instance = new FrontendEnvironmentDetector();
    }
    return FrontendEnvironmentDetector.instance;
  }

  /**
   * Detect the current deployment environment for frontend
   */
  public detectEnvironment(): FrontendEnvironmentInfo {
    if (this.cachedEnvironment) {
      return this.cachedEnvironment;
    }

    const environment = this.performEnvironmentDetection();
    this.cachedEnvironment = environment;
    return environment;
  }

  private performEnvironmentDetection(): FrontendEnvironmentInfo {
    // Check for explicit environment configuration
    const explicitEnv = this.getEnvironmentFromConfig();
    if (explicitEnv) {
      return this.createEnvironmentInfo(explicitEnv);
    }

    // Check URL patterns to determine environment
    const urlBasedEnv = this.detectFromURL();
    if (urlBasedEnv) {
      return this.createEnvironmentInfo(urlBasedEnv);
    }

    // Check for development environment
    if (this.isDevelopmentEnvironment()) {
      return this.createEnvironmentInfo(DeploymentEnvironment.DEVELOPMENT);
    }

    // Default to AWS for production builds
    return this.createEnvironmentInfo(DeploymentEnvironment.AWS);
  }

  private getEnvironmentFromConfig(): DeploymentEnvironment | null {
    // Check if environment is explicitly set in window object (injected by build process)
    if (typeof window !== 'undefined' && (window as any).APP_CONFIG) {
      const deploymentMode = (window as any).APP_CONFIG.DEPLOYMENT_MODE;
      if (deploymentMode === 'kubernetes') return DeploymentEnvironment.KUBERNETES;
      if (deploymentMode === 'aws') return DeploymentEnvironment.AWS;
    }

    // Check meta tags for environment configuration
    if (typeof document !== 'undefined') {
      const metaTag = document.querySelector('meta[name="deployment-mode"]');
      if (metaTag) {
        const content = metaTag.getAttribute('content');
        if (content === 'kubernetes') return DeploymentEnvironment.KUBERNETES;
        if (content === 'aws') return DeploymentEnvironment.AWS;
      }
    }

    return null;
  }

  private detectFromURL(): DeploymentEnvironment | null {
    if (typeof window === 'undefined') return null;

    const hostname = window.location.hostname;
    const pathname = window.location.pathname;

    // Development environment indicators
    if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname.endsWith('.local')) {
      return DeploymentEnvironment.DEVELOPMENT;
    }

    // Kubernetes environment indicators (cluster domains, ingress patterns)
    if (hostname.includes('.cluster.local') || 
        hostname.includes('k8s') || 
        hostname.includes('kube') ||
        this.hasKubernetesHeaders() ||
        this.hasKubernetesPathPattern(pathname)) {
      return DeploymentEnvironment.KUBERNETES;
    }

    // AWS environment indicators (CloudFront, S3, API Gateway patterns)
    if (hostname.includes('.amazonaws.com') ||
        hostname.includes('.cloudfront.net') ||
        hostname.includes('.s3-website') ||
        hostname.includes('.execute-api.')) {
      return DeploymentEnvironment.AWS;
    }

    return null;
  }

  private hasKubernetesHeaders(): boolean {
    // This would be set by ingress controllers or load balancers
    // We can't directly access response headers in frontend, but they might be
    // available through server-side rendering or injected during build
    return false;
  }

  private hasKubernetesPathPattern(pathname: string): boolean {
    // Check for Kubernetes ingress path patterns
    // Common patterns: /user, /admin, /ws for WebSocket
    return pathname.startsWith('/user') || 
           pathname.startsWith('/admin') || 
           pathname.includes('/ws');
  }

  private isDevelopmentEnvironment(): boolean {
    if (typeof window === 'undefined') return false;

    return (
      window.location.hostname === 'localhost' ||
      window.location.hostname === '127.0.0.1' ||
      window.location.port !== '' ||
      window.location.protocol === 'file:'
    );
  }

  private createEnvironmentInfo(environment: DeploymentEnvironment): FrontendEnvironmentInfo {
    return {
      environment,
      isAWS: environment === DeploymentEnvironment.AWS,
      isKubernetes: environment === DeploymentEnvironment.KUBERNETES,
      isDevelopment: environment === DeploymentEnvironment.DEVELOPMENT
    };
  }

  /**
   * Reset cached environment (useful for testing)
   */
  public resetCache(): void {
    this.cachedEnvironment = null;
  }

  /**
   * Force re-detection of environment (useful when environment might have changed)
   */
  public refreshEnvironment(): FrontendEnvironmentInfo {
    this.resetCache();
    return this.detectEnvironment();
  }

  /**
   * Check if environment has changed since last detection
   */
  public hasEnvironmentChanged(): boolean {
    if (!this.cachedEnvironment) return false;
    
    const currentEnv = this.performEnvironmentDetection();
    return currentEnv.environment !== this.cachedEnvironment.environment;
  }
}