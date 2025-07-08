#!/bin/bash

# Local test script for production configuration
set -e

echo "🧪 Starting local production test..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p web_ui/uploads
mkdir -p web_ui/results
mkdir -p static_files

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.local-test.yml down || true

# Build and start services
echo "🔨 Building and starting services..."
docker-compose -f docker-compose.local-test.yml up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service status
echo "🔍 Checking service status..."
docker-compose -f docker-compose.local-test.yml ps

echo "✅ Local test deployment completed!"
echo ""
echo "🌐 Your application should now be accessible at:"
echo "   - http://localhost:8080"
echo ""
echo "📋 To check logs:"
echo "   docker-compose -f docker-compose.local-test.yml logs -f"
echo ""
echo "🛑 To stop services:"
echo "   docker-compose -f docker-compose.local-test.yml down"
echo ""
echo "🧪 To test the API directly:"
echo "   curl http://localhost:8080/api/files" 