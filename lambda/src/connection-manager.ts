import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { createConnectionManager } from './connection';

const connectionManager = createConnectionManager();

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const { connectionId } = event.requestContext;
  const { eventType } = event.requestContext;

  console.log(`Connection event: ${eventType} for connection: ${connectionId}`);

  if (!connectionId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Connection ID is required' }),
    };
  }

  try {
    if (eventType === 'CONNECT') {
      // Store connection using abstraction layer
      await connectionManager.storeConnection(connectionId, 'admin'); // Default to admin, will be updated based on client identification
      
      console.log(`Connection ${connectionId} stored successfully`);
      
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Connected successfully' }),
      };
    } else if (eventType === 'DISCONNECT') {
      // Remove connection using abstraction layer
      await connectionManager.removeConnection(connectionId);

      console.log(`Connection ${connectionId} removed successfully`);
      
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Disconnected successfully' }),
      };
    }

    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Unknown event type' }),
    };
  } catch (error) {
    console.error('Error handling connection event:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error' }),
    };
  }
};