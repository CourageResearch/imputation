#!/bin/bash

# Firewall setup for Digital Ocean deployment
set -e

echo "🔥 Setting up firewall..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo "📦 Installing UFW..."
    apt update && apt install ufw -y
fi

# Reset UFW to default
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important: do this first!)
ufw allow ssh
ufw allow 22

# Allow HTTP and HTTPS
ufw allow 80
ufw allow 443

# Allow Docker ports (if needed for direct access)
# ufw allow 8000
# ufw allow 3000

# Enable UFW
ufw --force enable

echo "✅ Firewall configured successfully!"
echo ""
echo "📋 Firewall status:"
ufw status verbose

echo ""
echo "🔒 Firewall rules:"
ufw status numbered

echo ""
echo "⚠️  Important: Make sure you can still SSH to the server before closing this session!"
echo "   If you get locked out, you can reset the firewall from the Digital Ocean console." 