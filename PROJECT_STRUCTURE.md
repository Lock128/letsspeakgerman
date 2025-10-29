# User-Admin Messaging Application

## Project Structure

```
user-admin-messaging/
├── package.json                    # Root package.json with workspace configuration
├── .gitignore                      # Git ignore rules
├── PROJECT_STRUCTURE.md            # This file
├── infrastructure/                 # AWS CDK infrastructure code
│   ├── package.json               # CDK dependencies
│   ├── tsconfig.json              # TypeScript configuration for CDK
│   ├── cdk.json                   # CDK app configuration
│   ├── jest.config.js             # Jest configuration for CDK tests
│   └── src/                       # CDK source code (to be implemented)
├── lambda/                        # Lambda function code
│   ├── package.json               # Lambda dependencies
│   ├── tsconfig.json              # TypeScript configuration for Lambda
│   ├── jest.config.js             # Jest configuration for Lambda tests
│   └── src/                       # Lambda source code (to be implemented)
├── frontend/
│   ├── user/                      # User interface frontend
│   │   ├── package.json           # User frontend dependencies
│   │   ├── tsconfig.json          # TypeScript configuration
│   │   ├── jest.config.js         # Jest configuration
│   │   └── src/                   # User frontend source code (to be implemented)
│   └── admin/                     # Admin interface frontend
│       ├── package.json           # Admin frontend dependencies
│       ├── tsconfig.json          # TypeScript configuration
│       ├── jest.config.js         # Jest configuration
│       └── src/                   # Admin frontend source code (to be implemented)
└── .kiro/
    └── specs/
        └── user-admin-messaging/
            ├── requirements.md     # Feature requirements
            ├── design.md          # Technical design
            └── tasks.md           # Implementation tasks
```

## Getting Started

1. Install dependencies for all components:
   ```bash
   npm run install-all
   ```

2. Build all components:
   ```bash
   npm run build
   ```

3. Run tests:
   ```bash
   npm test
   ```

## Component Overview

- **infrastructure/**: AWS CDK code for deploying the serverless infrastructure
- **lambda/**: Node.js Lambda functions for WebSocket connection management and message handling
- **frontend/user/**: Static web application for users to send messages
- **frontend/admin/**: Static web application for administrators to receive messages

## Technology Stack

- **Infrastructure**: AWS CDK with TypeScript
- **Backend**: AWS Lambda with Node.js and TypeScript
- **Frontend**: Vanilla TypeScript with HTML/CSS
- **Testing**: Jest with TypeScript support
- **Build**: TypeScript compiler