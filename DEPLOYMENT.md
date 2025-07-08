# Digital Ocean Deployment Guide

This guide will help you deploy the Genome Imputation Pipeline to Digital Ocean with support for both IP address access and custom domain.

## Prerequisites

1. A Digital Ocean account
2. A domain name (optional, for `imputation.stadium.science`)
3. SSH access to your Digital Ocean droplet

## Step 1: Create a Digital Ocean Droplet

1. Log into your Digital Ocean account
2. Click "Create" → "Droplets"
3. Choose the following settings:
   - **Distribution**: Ubuntu 22.04 LTS
   - **Plan**: Basic
   - **Size**: At least 4GB RAM, 2 vCPUs (for genome processing)
   - **Datacenter**: Choose closest to your users
   - **Authentication**: SSH key (recommended) or password
   - **Hostname**: `imputation-server`

4. Click "Create Droplet"

## Step 2: Connect to Your Droplet

```bash
ssh root@YOUR_DROPLET_IP
```

## Step 3: Upload Your Code

### Option A: Using Git (Recommended)
```bash
# Install git
apt update && apt install git -y

# Clone your repository
git clone https://github.com/YOUR_USERNAME/imputation.git
cd imputation
```

### Option B: Using SCP
From your local machine:
```bash
scp -r /path/to/your/imputation root@YOUR_DROPLET_IP:/root/
ssh root@YOUR_DROPLET_IP
cd imputation
```

## Step 4: Deploy the Application

### Quick Start (HTTP Only)
For immediate deployment without SSL:

```bash
chmod +x deploy-http.sh
./deploy-http.sh
```

### Full Deployment (with HTTPS)
For production deployment with SSL:

```bash
chmod +x deploy.sh
./deploy.sh
```

## Step 5: Configure Domain (Optional)

If you want to use `imputation.stadium.science`:

1. **DNS Configuration**:
   - Go to your domain registrar's DNS settings
   - Add an A record:
     - **Name**: `imputation`
     - **Value**: Your Digital Ocean droplet IP
     - **TTL**: 300

2. **SSL Certificate** (for HTTPS):
   - The deployment script creates self-signed certificates
   - For production, replace with Let's Encrypt certificates:
   ```bash
   # Install certbot
   apt install certbot -y
   
   # Get SSL certificate
   certbot certonly --standalone -d imputation.stadium.science
   
   # Copy certificates
   cp /etc/letsencrypt/live/imputation.stadium.science/fullchain.pem ssl/cert.pem
   cp /etc/letsencrypt/live/imputation.stadium.science/privkey.pem ssl/key.pem
   
   # Restart services
   docker-compose -f docker-compose.prod.yml restart nginx
   ```

## Step 6: Verify Deployment

1. **Check if services are running**:
   ```bash
   docker-compose -f docker-compose.prod.http.yml ps
   # or
   docker-compose -f docker-compose.prod.yml ps
   ```

2. **Check logs**:
   ```bash
   docker-compose -f docker-compose.prod.http.yml logs -f
   # or
   docker-compose -f docker-compose.prod.yml logs -f
   ```

3. **Test the application**:
   - Visit `http://YOUR_DROPLET_IP`
   - Or visit `https://imputation.stadium.science` (if configured)

## Architecture Overview

The deployment uses the following services:

- **Nginx**: Reverse proxy serving on port 80/443
- **Frontend**: React app built and served by nginx
- **Backend**: FastAPI application running on port 8000
- **Imputation**: Processing service (started on-demand)

## File Structure

```
imputation/
├── docker-compose.prod.yml          # Production with HTTPS
├── docker-compose.prod.http.yml     # Production HTTP only
├── nginx.conf                       # HTTPS nginx config
├── nginx.conf.http                  # HTTP nginx config
├── deploy.sh                        # Full deployment script
├── deploy-http.sh                   # HTTP deployment script
├── ssl/                             # SSL certificates
├── web_ui/
│   ├── frontend/
│   │   ├── Dockerfile.prod          # Production frontend build
│   │   └── nginx.conf               # Frontend nginx config
│   └── backend/
│       └── main.py                  # FastAPI backend
└── static_files/                    # Genome reference files
```

## Troubleshooting

### Common Issues

1. **Port 80/443 already in use**:
   ```bash
   # Check what's using the ports
   netstat -tulpn | grep :80
   netstat -tulpn | grep :443
   
   # Stop conflicting services
   systemctl stop apache2
   systemctl stop nginx
   ```

2. **Docker permission issues**:
   ```bash
   # Add user to docker group
   usermod -aG docker $USER
   newgrp docker
   ```

3. **SSL certificate issues**:
   ```bash
   # Check certificate validity
   openssl x509 -in ssl/cert.pem -text -noout
   
   # Regenerate self-signed certificate
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -keyout ssl/key.pem \
       -out ssl/cert.pem \
       -subj "/C=US/ST=State/L=City/O=Organization/CN=imputation.stadium.science"
   ```

4. **Frontend not loading**:
   ```bash
   # Check frontend logs
   docker-compose -f docker-compose.prod.http.yml logs frontend
   
   # Rebuild frontend
   docker-compose -f docker-compose.prod.http.yml build frontend
   ```

### Performance Optimization

1. **Increase memory for genome processing**:
   ```bash
   # Edit docker-compose file
   environment:
     - JAVA_OPTS=-Xmx16g  # Increase from 8g to 16g
   ```

2. **Add swap space** (if needed):
   ```bash
   # Create 4GB swap
   fallocate -l 4G /swapfile
   chmod 600 /swapfile
   mkswap /swapfile
   swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   ```

## Maintenance

### Updating the Application
```bash
# Pull latest code
git pull

# Rebuild and restart
docker-compose -f docker-compose.prod.http.yml down
docker-compose -f docker-compose.prod.http.yml up -d --build
```

### Backup
```bash
# Backup uploads and results
tar -czf backup-$(date +%Y%m%d).tar.gz web_ui/uploads web_ui/results
```

### Monitoring
```bash
# Check resource usage
docker stats

# Monitor logs
docker-compose -f docker-compose.prod.http.yml logs -f --tail=100
```

## Security Considerations

1. **Firewall**: Configure UFW to only allow necessary ports
2. **SSL**: Use Let's Encrypt certificates for production
3. **Updates**: Regularly update the system and Docker images
4. **Backups**: Set up regular backups of user data
5. **Monitoring**: Consider setting up monitoring and alerting

## Support

If you encounter issues:
1. Check the logs: `docker-compose logs -f`
2. Verify all services are running: `docker-compose ps`
3. Check system resources: `htop`, `df -h`
4. Review this documentation for troubleshooting steps 