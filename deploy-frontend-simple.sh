#!/bin/bash

set -e

echo "🚀 Simple frontend deployment"

# Build both frontends
echo "Building user frontend..."
cd frontend/user && npm run build && cd ../..

echo "Building admin frontend..."
cd frontend/admin && npm run build && cd ../..

# Deploy to S3 (you'll need to update AWS credentials first)
echo "Deploying user frontend..."
aws s3 sync frontend/user/dist/ s3://user-admin-messaging-user-dev-916032256060-eu-central-1/ --delete

echo "Deploying admin frontend..."
aws s3 sync frontend/admin/dist/ s3://user-admin-messaging-admin-dev-916032256060-eu-central-1/ --delete

echo "✅ Deployment complete"
echo "User: https://drm7z573qqoa2.cloudfront.net/user/"
echo "Admin: https://drm7z573qqoa2.cloudfront.net/admin/"