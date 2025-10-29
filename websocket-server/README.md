# WebSocket Server for Kubernetes Deployment

This is a standalone WebSocket server designed for Kubernetes deployment as part of the user-admin-messaging application.

## Features

- **WebSocket Server**: Express.js server with WebSocket support using the `ws` library
- **Connection Management**: Redis-based connection storage for Kubernetes environments
- **Health Checks**: Kubernetes-compatible health check endpoints
- **Graceful Shutdown**: Proper SIGTERM handling for container environments
- **Monitoring**: Built-in metrics collection and monitoring endpoints

## Endpoints

### WebSocket
- `ws://localhost:8080/ws` - Main WebSocket endpoint

### Health Checks
- `GET /health` - Liveness probe endpoint
- `GET /ready` - Readiness probe endpoint  
- `GET /metrics` - Detailed metrics for monitoring

## Environment Variables

- `PORT` - WebSocket server port (default: 8080)
- `HEALTH_PORT` - Health check server port (default: 8081)
- `REDIS_URL` - Redis connection string (default: redis://redis-service:6379)
- `REDIS_PASSWORD` - Redis password (optional)
- `CONNECTION_TTL` - Connection TTL in seconds (default: 86400)

## Usage

### Development
```bash
npm install
npm run dev
```

### Production
```bash
npm install
npm run build
npm start
```

### Docker
```bash
docker build -t websocket-server .
docker run -p 8080:8080 -p 8081:8081 websocket-server
```

## Message Protocol

### Set Connection Type
```json
{
  "action": "setConnectionType",
  "data": {
    "connectionType": "user" | "admin"
  }
}
```

### Send Message
```json
{
  "action": "sendMessage", 
  "data": {
    "content": "message content"
  }
}
```

## Health Check Responses

### Liveness Probe (`/health`)
```json
{
  "status": "healthy",
  "connectionCount": 5,
  "redisConnected": true,
  "uptime": 12345,
  "timestamp": "2023-10-29T10:00:00.000Z",
  "version": "1.0.0"
}
```

### Readiness Probe (`/ready`)
```json
{
  "ready": true,
  "checks": {
    "redis": true,
    "server": true
  },
  "timestamp": "2023-10-29T10:00:00.000Z"
}
```