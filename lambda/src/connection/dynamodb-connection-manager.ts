/**
 * DynamoDB Connection Manager
 * Implements connection management using AWS DynamoDB for Lambda environments
 */

import * as AWS from 'aws-sdk';
import { ConnectionManager, ConnectionMetadata } from './connection-manager-interface';
import { ConfigurationAdapterFactory } from '../config/configuration-adapter';

export class DynamoDBConnectionManager implements ConnectionManager {
  private dynamodb: AWS.DynamoDB.DocumentClient;
  private tableName: string;
  private ttl: number;

  constructor() {
    this.dynamodb = new AWS.DynamoDB.DocumentClient();
    
    const adapter = ConfigurationAdapterFactory.createAdapter();
    const storageConfig = adapter.getStorageConfig();
    
    this.tableName = storageConfig.tableName || 'websocket-connections';
    this.ttl = storageConfig.ttl;
  }

  async storeConnection(
    connectionId: string, 
    connectionType: 'user' | 'admin', 
    metadata?: Partial<ConnectionMetadata>
  ): Promise<void> {
    const timestamp = Date.now();
    const ttlValue = Math.floor(Date.now() / 1000) + this.ttl;

    const item: ConnectionMetadata & { ttl: number } = {
      connectionId,
      connectionType,
      timestamp,
      ttl: ttlValue,
      ...metadata
    };

    try {
      await this.dynamodb.put({
        TableName: this.tableName,
        Item: item,
      }).promise();

      console.log(`Connection ${connectionId} stored in DynamoDB with type: ${connectionType}`);
    } catch (error) {
      console.error(`Failed to store connection ${connectionId}:`, error);
      throw new Error(`Failed to store connection: ${error}`);
    }
  }

  async removeConnection(connectionId: string): Promise<void> {
    try {
      await this.dynamodb.delete({
        TableName: this.tableName,
        Key: { connectionId },
      }).promise();

      console.log(`Connection ${connectionId} removed from DynamoDB`);
    } catch (error) {
      console.error(`Failed to remove connection ${connectionId}:`, error);
      throw new Error(`Failed to remove connection: ${error}`);
    }
  }

  async getConnections(connectionType: 'user' | 'admin'): Promise<string[]> {
    try {
      const result = await this.dynamodb.scan({
        TableName: this.tableName,
        FilterExpression: 'connectionType = :type',
        ExpressionAttributeValues: {
          ':type': connectionType,
        },
        ProjectionExpression: 'connectionId',
      }).promise();

      return (result.Items || []).map(item => item.connectionId);
    } catch (error) {
      console.error(`Failed to get connections of type ${connectionType}:`, error);
      throw new Error(`Failed to get connections: ${error}`);
    }
  }

  async getConnectionMetadata(connectionId: string): Promise<ConnectionMetadata | null> {
    try {
      const result = await this.dynamodb.get({
        TableName: this.tableName,
        Key: { connectionId },
      }).promise();

      if (!result.Item) {
        return null;
      }

      return {
        connectionId: result.Item.connectionId,
        connectionType: result.Item.connectionType,
        timestamp: result.Item.timestamp,
        ttl: result.Item.ttl,
      };
    } catch (error) {
      console.error(`Failed to get metadata for connection ${connectionId}:`, error);
      throw new Error(`Failed to get connection metadata: ${error}`);
    }
  }

  async updateConnectionType(connectionId: string, connectionType: 'user' | 'admin'): Promise<void> {
    try {
      await this.dynamodb.update({
        TableName: this.tableName,
        Key: { connectionId },
        UpdateExpression: 'SET connectionType = :type',
        ExpressionAttributeValues: {
          ':type': connectionType,
        },
      }).promise();

      console.log(`Connection ${connectionId} type updated to: ${connectionType}`);
    } catch (error) {
      console.error(`Failed to update connection type for ${connectionId}:`, error);
      throw new Error(`Failed to update connection type: ${error}`);
    }
  }

  async connectionExists(connectionId: string): Promise<boolean> {
    try {
      const result = await this.dynamodb.get({
        TableName: this.tableName,
        Key: { connectionId },
        ProjectionExpression: 'connectionId',
      }).promise();

      return !!result.Item;
    } catch (error) {
      console.error(`Failed to check if connection ${connectionId} exists:`, error);
      return false;
    }
  }

  async cleanupExpiredConnections(): Promise<void> {
    // DynamoDB TTL handles automatic cleanup, but we can implement manual cleanup if needed
    const currentTime = Math.floor(Date.now() / 1000);
    
    try {
      const result = await this.dynamodb.scan({
        TableName: this.tableName,
        FilterExpression: 'attribute_exists(#ttl) AND #ttl < :currentTime',
        ExpressionAttributeNames: {
          '#ttl': 'ttl',
        },
        ExpressionAttributeValues: {
          ':currentTime': currentTime,
        },
        ProjectionExpression: 'connectionId',
      }).promise();

      const expiredConnections = result.Items || [];
      
      if (expiredConnections.length > 0) {
        console.log(`Found ${expiredConnections.length} expired connections to clean up`);
        
        const deletePromises = expiredConnections.map(item =>
          this.dynamodb.delete({
            TableName: this.tableName,
            Key: { connectionId: item.connectionId },
          }).promise()
        );

        await Promise.all(deletePromises);
        console.log(`Cleaned up ${expiredConnections.length} expired connections`);
      }
    } catch (error) {
      console.error('Failed to cleanup expired connections:', error);
      throw new Error(`Failed to cleanup expired connections: ${error}`);
    }
  }
}