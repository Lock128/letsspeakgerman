import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { UserAdminMessagingStack } from '../user-admin-messaging-stack';

describe('UserAdminMessagingStack', () => {
  let template: Template;

  beforeEach(() => {
    const app = new cdk.App();
    const stack = new UserAdminMessagingStack(app, 'TestStack', {
      environment: 'test',
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });
    template = Template.fromStack(stack);
  });

  it('should create DynamoDB table', () => {
    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'websocket-connections-test',
      BillingMode: 'PAY_PER_REQUEST',
    });
  });

  it('should create WebSocket API', () => {
    template.hasResourceProperties('AWS::ApiGatewayV2::Api', {
      Name: 'user-admin-messaging-websocket-test',
      ProtocolType: 'WEBSOCKET',
    });
  });

  it('should create Lambda functions', () => {
    template.resourceCountIs('AWS::Lambda::Function', 3);
    template.hasResourceProperties('AWS::Lambda::Function', {
      Runtime: 'nodejs22.x',
      Handler: 'connection-manager.handler',
    });
    template.hasResourceProperties('AWS::Lambda::Function', {
      Runtime: 'nodejs22.x',
      Handler: 'message-handler.handler',
    });
  });

  it('should create S3 bucket', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      WebsiteConfiguration: {
        IndexDocument: 'index.html',
        ErrorDocument: 'error.html',
      },
    });
  });

  it('should create CloudFront distribution', () => {
    template.hasResourceProperties('AWS::CloudFront::Distribution', {
      DistributionConfig: {
        DefaultRootObject: 'index.html',
      },
    });
  });
});