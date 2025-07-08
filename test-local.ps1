# Local test script for production configuration (PowerShell)
Write-Host "🧪 Starting local production test..." -ForegroundColor Green

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Create necessary directories
Write-Host "📁 Creating necessary directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "web_ui/uploads" | Out-Null
New-Item -ItemType Directory -Force -Path "web_ui/results" | Out-Null
New-Item -ItemType Directory -Force -Path "static_files" | Out-Null

# Stop any existing containers
Write-Host "🛑 Stopping existing containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.local-test.yml down 2>$null

# Build and start services
Write-Host "🔨 Building and starting services..." -ForegroundColor Yellow
docker-compose -f docker-compose.local-test.yml up -d --build

# Wait for services to be ready
Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check service status
Write-Host "🔍 Checking service status..." -ForegroundColor Yellow
docker-compose -f docker-compose.local-test.yml ps

Write-Host "✅ Local test deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Your application should now be accessible at:" -ForegroundColor Cyan
Write-Host "   - http://localhost:8080" -ForegroundColor White
Write-Host ""
Write-Host "📋 To check logs:" -ForegroundColor Cyan
Write-Host "   docker-compose -f docker-compose.local-test.yml logs -f" -ForegroundColor White
Write-Host ""
Write-Host "🛑 To stop services:" -ForegroundColor Cyan
Write-Host "   docker-compose -f docker-compose.local-test.yml down" -ForegroundColor White
Write-Host ""
Write-Host "🧪 To test the API directly:" -ForegroundColor Cyan
Write-Host "   Invoke-RestMethod http://localhost:8080/api/files" -ForegroundColor White 