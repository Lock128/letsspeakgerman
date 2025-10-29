#!/bin/bash

# Build script for all frontend applications
# Usage: ./scripts/build-all.sh [options]

set -e

# Default values
CLEAN=false
WATCH=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --clean)
      CLEAN=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --clean              Clean dist directories before building"
      echo "  --watch              Watch for changes and rebuild automatically"
      echo "  -h, --help           Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "🔨 Building frontend applications"
echo ""

# Clean if requested
if [[ "$CLEAN" == true ]]; then
  echo "🧹 Cleaning build directories..."
  cd user && npm run clean && cd ../admin && npm run clean && cd ..
  echo "✅ Clean completed"
fi

# Build or watch
if [[ "$WATCH" == true ]]; then
  echo "👀 Starting watch mode for both frontends..."
  echo "   User interface: http://localhost:8000"
  echo "   Admin interface: http://localhost:8001"
  echo ""
  echo "Press Ctrl+C to stop watching"
  
  # Start both watch processes in background
  cd user && npm run watch &
  USER_PID=$!
  cd ../admin && npm run watch &
  ADMIN_PID=$!
  cd ..
  
  # Start local servers
  cd user && npm run serve &
  USER_SERVER_PID=$!
  cd ../admin && npm run serve &
  ADMIN_SERVER_PID=$!
  cd ..
  
  # Wait for interrupt
  trap "echo ''; echo '🛑 Stopping watch mode...'; kill $USER_PID $ADMIN_PID $USER_SERVER_PID $ADMIN_SERVER_PID 2>/dev/null; exit 0" INT
  wait
else
  echo "🔨 Building user interface..."
  cd user && npm run build && cd ..
  echo "✅ User interface built successfully"
  
  echo "🔨 Building admin interface..."
  cd admin && npm run build && cd ..
  echo "✅ Admin interface built successfully"
  
  echo ""
  echo "✅ All frontend applications built successfully!"
  echo ""
  echo "📁 Build outputs:"
  echo "   User interface: frontend/user/dist/"
  echo "   Admin interface: frontend/admin/dist/"
  echo ""
  echo "🚀 To deploy:"
  echo "   npm run deploy:frontend:dev    # Deploy both to dev"
  echo "   npm run deploy:frontend:staging # Deploy both to staging"
  echo "   npm run deploy:frontend:prod   # Deploy both to prod"
fi