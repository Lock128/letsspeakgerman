import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import * as AWS from 'aws-sdk';
import { createConnectionManager } from './connection';

const connectionManager = createConnectionManager();
const apigateway = new AWS.ApiGatewayManagementApi({
  endpoint: process.env.WEBSOCKET_API_ENDPOINT,
});

interface MessageData {
  action: string;
  data?: {
    content?: string;
    connectionType?: string;
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const { connectionId } = event.requestContext;
  
  console.log(`Message received from connection: ${connectionId}`);
  console.log('Event body:', event.body);

  if (!connectionId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Connection ID is required' }),
    };
  }

  try {
    const messageData: MessageData = JSON.parse(event.body || '{}');
    
    if (messageData.action === 'sendMessage') {
      // This is a message from user interface - broadcast to admin connections
      const message = {
        content: messageData.data?.content || 'speak german',
        timestamp: new Date().toISOString(),
        from: 'user',
      };

      // Get all admin connections using abstraction layer
      const adminConnectionIds = await connectionManager.getConnections('admin');

      console.log(`Found ${adminConnectionIds.length} admin connections`);

      // Send message to all admin connections
      const sendPromises = adminConnectionIds.map(async (adminConnectionId: string) => {
        try {
          await apigateway.postToConnection({
            ConnectionId: adminConnectionId,
            Data: JSON.stringify(message),
          }).promise();
          console.log(`Message sent to admin connection: ${adminConnectionId}`);
        } catch (error: any) {
          console.error(`Failed to send message to ${adminConnectionId}:`, error);
          
          // If connection is stale, remove it using abstraction layer
          if (error.statusCode === 410) {
            await connectionManager.removeConnection(adminConnectionId);
            console.log(`Removed stale connection: ${adminConnectionId}`);
          }
        }
      });

      await Promise.all(sendPromises);

      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Message sent to admin connections' }),
      };
    } else if (messageData.action === 'setConnectionType') {
      // Update connection type using abstraction layer
      const connectionType = messageData.data?.connectionType || 'admin';
      
      // Validate connection type
      if (connectionType !== 'user' && connectionType !== 'admin') {
        return {
          statusCode: 400,
          body: JSON.stringify({ message: 'Invalid connection type. Must be "user" or "admin"' }),
        };
      }
      
      await connectionManager.updateConnectionType(connectionId, connectionType as 'user' | 'admin');

      console.log(`Connection ${connectionId} type set to: ${connectionType}`);

      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Connection type updated' }),
      };
    }

    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Unknown action' }),
    };
  } catch (error) {
    console.error('Error handling message:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error' }),
    };
  }
};