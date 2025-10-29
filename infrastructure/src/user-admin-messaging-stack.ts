import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as apigatewayv2 from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigatewayv2Integrations from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import * as path from 'path';

export interface UserAdminMessagingStackProps extends cdk.StackProps {
  environment: string;
  removalPolicy: cdk.RemovalPolicy;
  autoDeleteObjects: boolean;
}

export class UserAdminMessagingStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: UserAdminMessagingStackProps) {
    super(scope, id, props);

    const { environment, removalPolicy, autoDeleteObjects } = props;

    // DynamoDB table for WebSocket connections
    const connectionsTable = new dynamodb.Table(this, 'WebSocketConnections', {
      tableName: `websocket-connections-${environment}`,
      partitionKey: {
        name: 'connectionId',
        type: dynamodb.AttributeType.STRING,
      },
      timeToLiveAttribute: 'ttl',
      removalPolicy,
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
    });

    // Add GSI for querying by connection type
    connectionsTable.addGlobalSecondaryIndex({
      indexName: 'ConnectionTypeIndex',
      partitionKey: {
        name: 'connectionType',
        type: dynamodb.AttributeType.STRING,
      },
    });

    // WebSocket API Gateway
    const webSocketApi = new apigatewayv2.WebSocketApi(this, 'WebSocketApi', {
      apiName: `user-admin-messaging-websocket-${environment}`,
      description: `WebSocket API for real-time messaging between user and admin interfaces (${environment})`,
    });

    // WebSocket API Stage
    const webSocketStage = new apigatewayv2.WebSocketStage(this, 'WebSocketStage', {
      webSocketApi,
      stageName: 'prod',
      autoDeploy: true,
    });

    // Lambda function for connection management
    const connectionManagerFunction = new lambda.Function(this, 'ConnectionManagerFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'connection-manager.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '../../lambda/dist')),
      environment: {
        CONNECTIONS_TABLE_NAME: connectionsTable.tableName,
      },
    });

    // Lambda function for message handling
    const messageHandlerFunction = new lambda.Function(this, 'MessageHandlerFunction', {
      runtime: lambda.Runtime.NODEJS_18_X,
      handler: 'message-handler.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '../../lambda/dist')),
      environment: {
        CONNECTIONS_TABLE_NAME: connectionsTable.tableName,
        WEBSOCKET_API_ENDPOINT: `https://${webSocketApi.apiId}.execute-api.${this.region}.amazonaws.com/${webSocketStage.stageName}`,
      },
    });

    // Grant Lambda functions permissions to access DynamoDB
    connectionsTable.grantReadWriteData(connectionManagerFunction);
    connectionsTable.grantReadWriteData(messageHandlerFunction);

    // Grant message handler permission to post to WebSocket connections
    messageHandlerFunction.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['execute-api:ManageConnections'],
      resources: [`arn:aws:execute-api:${this.region}:${this.account}:${webSocketApi.apiId}/${webSocketStage.stageName}/POST/@connections/*`],
    }));

    // WebSocket API Routes
    const connectRoute = new apigatewayv2.WebSocketRoute(this, 'ConnectRoute', {
      webSocketApi,
      routeKey: '$connect',
      integration: new apigatewayv2Integrations.WebSocketLambdaIntegration('ConnectIntegration', connectionManagerFunction),
    });

    const disconnectRoute = new apigatewayv2.WebSocketRoute(this, 'DisconnectRoute', {
      webSocketApi,
      routeKey: '$disconnect',
      integration: new apigatewayv2Integrations.WebSocketLambdaIntegration('DisconnectIntegration', connectionManagerFunction),
    });

    const sendMessageRoute = new apigatewayv2.WebSocketRoute(this, 'SendMessageRoute', {
      webSocketApi,
      routeKey: 'sendMessage',
      integration: new apigatewayv2Integrations.WebSocketLambdaIntegration('SendMessageIntegration', messageHandlerFunction),
    });

    const setConnectionTypeRoute = new apigatewayv2.WebSocketRoute(this, 'SetConnectionTypeRoute', {
      webSocketApi,
      routeKey: 'setConnectionType',
      integration: new apigatewayv2Integrations.WebSocketLambdaIntegration('SetConnectionTypeIntegration', messageHandlerFunction),
    });

    // S3 bucket for user interface
    const userInterfaceBucket = new s3.Bucket(this, 'UserInterfaceBucket', {
      bucketName: `user-admin-messaging-user-${environment}-${this.account}-${this.region}`,
      websiteIndexDocument: 'index.html',
      websiteErrorDocument: 'error.html',
      publicReadAccess: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ACLS,
      removalPolicy,
      autoDeleteObjects,
    });

    // S3 bucket for admin interface
    const adminInterfaceBucket = new s3.Bucket(this, 'AdminInterfaceBucket', {
      bucketName: `user-admin-messaging-admin-${environment}-${this.account}-${this.region}`,
      websiteIndexDocument: 'index.html',
      websiteErrorDocument: 'error.html',
      publicReadAccess: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ACLS,
      removalPolicy,
      autoDeleteObjects,
    });

    // Output S3 bucket names and website URLs
    new cdk.CfnOutput(this, 'UserInterfaceBucketName', {
      value: userInterfaceBucket.bucketName,
      description: 'S3 bucket name for user interface',
    });

    new cdk.CfnOutput(this, 'AdminInterfaceBucketName', {
      value: adminInterfaceBucket.bucketName,
      description: 'S3 bucket name for admin interface',
    });

    new cdk.CfnOutput(this, 'UserInterfaceWebsiteUrl', {
      value: userInterfaceBucket.bucketWebsiteUrl,
      description: 'S3 website URL for user interface',
    });

    new cdk.CfnOutput(this, 'AdminInterfaceWebsiteUrl', {
      value: adminInterfaceBucket.bucketWebsiteUrl,
      description: 'S3 website URL for admin interface',
    });

    // CloudFront distribution with multiple origins
    const distribution = new cloudfront.Distribution(this, 'WebsiteDistribution', {
      defaultBehavior: {
        origin: new origins.S3StaticWebsiteOrigin(userInterfaceBucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
      },
      additionalBehaviors: {
        '/admin/*': {
          origin: new origins.S3StaticWebsiteOrigin(adminInterfaceBucket),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        },
        '/user/*': {
          origin: new origins.S3StaticWebsiteOrigin(userInterfaceBucket),
          viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        },
      },
      defaultRootObject: 'index.html',
      errorResponses: [
        {
          httpStatus: 404,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.minutes(30),
        },
        {
          httpStatus: 403,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.minutes(30),
        },
      ],
    });

    // Output CloudFront distribution domain name
    new cdk.CfnOutput(this, 'CloudFrontDistributionDomainName', {
      value: distribution.distributionDomainName,
      description: 'CloudFront distribution domain name',
    });

    new cdk.CfnOutput(this, 'CloudFrontDistributionUrl', {
      value: `https://${distribution.distributionDomainName}`,
      description: 'CloudFront distribution URL',
    });

    new cdk.CfnOutput(this, 'UserInterfaceUrl', {
      value: `https://${distribution.distributionDomainName}/user/`,
      description: 'User interface URL via CloudFront',
    });

    new cdk.CfnOutput(this, 'AdminInterfaceUrl', {
      value: `https://${distribution.distributionDomainName}/admin/`,
      description: 'Admin interface URL via CloudFront',
    });

    // Output the WebSocket URL for frontend configuration
    new cdk.CfnOutput(this, 'WebSocketUrl', {
      value: webSocketStage.url,
      description: 'WebSocket API URL',
    });
  }
}