const mockGetConnections = jest.fn();
const mockUpdateConnectionType = jest.fn();
const mockSend = jest.fn();

jest.mock('../connection', () => ({
  createConnectionManager: () => ({
    getConnections: mockGetConnections,
    updateConnectionType: mockUpdateConnectionType,
  }),
}));

jest.mock('@aws-sdk/client-apigatewaymanagementapi', () => ({
  ApiGatewayManagementApiClient: jest.fn(() => ({
    send: mockSend,
  })),
  PostToConnectionCommand: jest.fn(),
}));

import { handler } from '../message-handler';

describe('Message Handler', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should handle sendMessage action', async () => {
    mockGetConnections.mockResolvedValue(['admin-conn-1']);
    mockSend.mockResolvedValue({});

    const event = {
      requestContext: { connectionId: 'user-conn-1' },
      body: JSON.stringify({ action: 'sendMessage', data: { content: 'test message' } }),
    } as any;

    const result = await handler(event);

    expect(mockGetConnections).toHaveBeenCalledWith('admin');
    expect(result.statusCode).toBe(200);
  });

  it('should handle setConnectionType action', async () => {
    const event = {
      requestContext: { connectionId: 'test-conn-1' },
      body: JSON.stringify({ action: 'setConnectionType', data: { connectionType: 'user' } }),
    } as any;

    const result = await handler(event);

    expect(mockUpdateConnectionType).toHaveBeenCalledWith('test-conn-1', 'user');
    expect(result.statusCode).toBe(200);
  });

  it('should return 400 for invalid connection type', async () => {
    const event = {
      requestContext: { connectionId: 'test-conn-1' },
      body: JSON.stringify({ action: 'setConnectionType', data: { connectionType: 'invalid' } }),
    } as any;

    const result = await handler(event);

    expect(result.statusCode).toBe(400);
  });
});