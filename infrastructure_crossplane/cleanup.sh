#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
NAMESPACE=${2:-default}

echo "Cleaning up User-Admin Messaging infrastructure for environment: $ENVIRONMENT"

# Delete the claim
if kubectl get useradminmessaging "user-admin-messaging-$ENVIRONMENT" -n "$NAMESPACE" &> /dev/null; then
    echo "Deleting claim for environment: $ENVIRONMENT"
    kubectl delete useradminmessaging "user-admin-messaging-$ENVIRONMENT" -n "$NAMESPACE"
    
    echo "Waiting for resources to be cleaned up..."
    kubectl wait --for=delete useradminmessaging "user-admin-messaging-$ENVIRONMENT" -n "$NAMESPACE" --timeout=600s
else
    echo "No claim found for environment: $ENVIRONMENT"
fi

echo "Cleanup completed for environment: $ENVIRONMENT"