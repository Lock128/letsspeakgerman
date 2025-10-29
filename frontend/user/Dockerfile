# Multi-stage Docker build for User Frontend
# Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Set working directory
WORKDIR /app

# Copy and build shared config first
COPY frontend/shared/ ./frontend/shared/
WORKDIR /app/frontend/shared
# Clean any existing build files and rebuild
RUN rm -rf config/*.js && npm install && npm install @types/node --save-dev && npm run build

# Set working directory to user frontend
WORKDIR /app/frontend/user

# Create a clean package.json without workspace dependencies
RUN echo '{ \
  "name": "user-admin-messaging-user-frontend", \
  "version": "1.0.0", \
  "description": "User interface for user-admin messaging application", \
  "main": "dist/index.js", \
  "scripts": { \
    "build": "tsc && cp src/*.html dist/ && cp src/*.css dist/" \
  }, \
  "devDependencies": { \
    "@types/node": "^18.15.0", \
    "typescript": "^5.0.0" \
  }, \
  "engines": { \
    "node": ">=18.0.0" \
  } \
}' > package.json

# Install dependencies
RUN npm install

# Copy TypeScript config and source code
COPY frontend/user/tsconfig.json ./
COPY frontend/user/src/ ./src/

# Copy shared files for compilation
RUN mkdir -p shared && \
    cp -r /app/frontend/shared/config shared/

# Create a custom tsconfig for Docker build
RUN echo '{ \
  "compilerOptions": { \
    "target": "ES2020", \
    "module": "ES2020", \
    "lib": ["ES2020", "DOM", "DOM.Iterable"], \
    "outDir": "./dist", \
    "strict": true, \
    "esModuleInterop": true, \
    "skipLibCheck": true, \
    "forceConsistentCasingInFileNames": true, \
    "moduleResolution": "node", \
    "allowImportingTsExtensions": false, \
    "noEmit": false \
  }, \
  "include": ["src/**/*", "shared/**/*"], \
  "exclude": ["dist", "node_modules"] \
}' > tsconfig.docker.json

# Build the application and fix imports
RUN npx tsc -p tsconfig.docker.json && \
    cp src/*.html dist/ && \
    cp src/*.css dist/ && \
    # Copy the pre-built shared files from the shared build stage
    mkdir -p dist/shared && \
    echo "Checking shared build files:" && \
    ls -la /app/frontend/shared/config/ && \
    echo "Checking for loadDevelopmentConfiguration in shared JS:" && \
    grep -A 5 "loadDevelopmentConfiguration" /app/frontend/shared/config/configuration-manager.js || echo "Method not found" && \
    cp -r /app/frontend/shared/config dist/shared/ && \
    cp dist/src/*.js dist/ && \
    # Fix import statements to include .js extensions in all files
    echo "Fixing import statements..." && \
    sed -i "s/configuration-manager';/configuration-manager.js';/g" dist/shared/config/*.js && \
    sed -i "s/environment-detector';/environment-detector.js';/g" dist/shared/config/*.js && \
    sed -i "s/websocket-adapter';/websocket-adapter.js';/g" dist/shared/config/*.js && \
    echo "Import statements fixed." && \
    echo "Verifying fixes:" && \
    grep "environment-detector" dist/shared/config/configuration-manager.js || echo "No environment-detector imports found"

# Production stage
FROM nginx:alpine AS production

# Create non-root user for security
RUN adduser -S frontend -u 1001 -G nginx

# Copy built application from builder stage
COPY --from=builder /app/frontend/user/dist /usr/share/nginx/html

# Create optimized Nginx configuration
RUN cat > /etc/nginx/nginx.conf << 'EOF'
user frontend;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Handle HTML files
        location ~* \.html$ {
            expires -1;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }

        # Handle shared module imports (resolve ../shared to ./shared)
        location ~ ^/shared/(.*)$ {
            try_files /shared/$1 =404;
        }

        # Fallback to index.html for SPA routing
        location / {
            try_files $uri $uri/ /index.html;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Change ownership of nginx directories
RUN chown -R frontend:nginx /var/cache/nginx && \
    chown -R frontend:nginx /var/log/nginx && \
    chown -R frontend:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R frontend:nginx /var/run/nginx.pid

# Switch to non-root user
USER frontend

# Expose port 80
EXPOSE 80

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]