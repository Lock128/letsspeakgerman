#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { UserAdminMessagingStack } from './user-admin-messaging-stack';

const app = new cdk.App();

// Get environment from context or default to 'dev'
const environment = app.node.tryGetContext('environment') || 'dev';
const stackName = `UserAdminMessaging-${environment}`;

// Environment-specific configuration
const envConfig = {
  dev: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1',
    removalPolicy: cdk.RemovalPolicy.DESTROY,
    autoDeleteObjects: true,
  },
  staging: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1',
    removalPolicy: cdk.RemovalPolicy.RETAIN,
    autoDeleteObjects: false,
  },
  prod: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'eu-central-1',
    removalPolicy: cdk.RemovalPolicy.RETAIN,
    autoDeleteObjects: false,
  },
};

const config = envConfig[environment as keyof typeof envConfig] || envConfig.dev;

new UserAdminMessagingStack(app, stackName, {
  env: {
    account: config.account,
    region: config.region,
  },
  environment,
  removalPolicy: config.removalPolicy,
  autoDeleteObjects: config.autoDeleteObjects,
});