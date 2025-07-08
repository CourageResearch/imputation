#!/bin/bash

# Digital Ocean Deployment Script for Genome Imputation Pipeline
set -e

echo "🚀 Starting deployment..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Docker and Docker Compose if not already installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create SSL directory
mkdir -p ssl

# Check if SSL certificates exist
if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.pem" ]; then
    echo "🔒 SSL certificates not found. Creating self-signed certificates for testing..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=imputation.stadium.science"
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p web_ui/uploads
mkdir -p web_ui/results
mkdir -p static_files

# Set proper permissions
chmod 755 web_ui/uploads
chmod 755 web_ui/results
chmod 755 static_files

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down || true

# Build and start services
echo "🔨 Building and starting services..."
docker-compose -f docker-compose.prod.yml up -d --build

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service status
echo "🔍 Checking service status..."
docker-compose -f docker-compose.prod.yml ps

echo "✅ Deployment completed!"
echo ""
echo "🌐 Your application should now be accessible at:"
echo "   - HTTP: http://$(curl -s ifconfig.me)"
echo "   - HTTPS: https://imputation.stadium.science (if DNS is configured)"
echo ""
echo "📋 To check logs:"
echo "   docker-compose -f docker-compose.prod.yml logs -f"
echo ""
echo "🛑 To stop services:"
echo "   docker-compose -f docker-compose.prod.yml down" 