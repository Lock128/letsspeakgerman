const mockStoreConnection = jest.fn();
const mockRemoveConnection = jest.fn();

jest.mock('../connection', () => ({
  createConnectionManager: () => ({
    storeConnection: mockStoreConnection,
    removeConnection: mockRemoveConnection,
  }),
}));

import { handler } from '../connection-manager';

describe('Connection Manager', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should handle CONNECT event', async () => {
    const event = {
      requestContext: {
        connectionId: 'test-connection-id',
        eventType: 'CONNECT',
      },
    } as any;

    const result = await handler(event);

    expect(mockStoreConnection).toHaveBeenCalledWith('test-connection-id', 'admin');
    expect(result.statusCode).toBe(200);
  });

  it('should handle DISCONNECT event', async () => {
    const event = {
      requestContext: {
        connectionId: 'test-connection-id',
        eventType: 'DISCONNECT',
      },
    } as any;

    const result = await handler(event);

    expect(mockRemoveConnection).toHaveBeenCalledWith('test-connection-id');
    expect(result.statusCode).toBe(200);
  });

  it('should return 400 for missing connection ID', async () => {
    const event = {
      requestContext: {
        eventType: 'CONNECT',
      },
    } as any;

    const result = await handler(event);

    expect(result.statusCode).toBe(400);
  });
});