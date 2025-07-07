# Genome Imputation Web UI

A web interface for the genome imputation pipeline with file upload, processing, and download capabilities.

## Project Structure

```
web_ui/
├── backend/          # FastAPI backend
├── frontend/         # React frontend
├── uploads/          # Uploaded files (UUID-based)
└── results/          # Processed results (UUID-based)
```

## Setup Instructions

### 1. Backend Setup

```bash
cd web_ui/backend
pip install -r requirements.txt
python main.py
```

The FastAPI server will run on `http://localhost:8000`

### 2. Frontend Setup

```bash
cd web_ui/frontend
npm install
npm start
```

The React app will run on `http://localhost:3000`

### 3. Docker Setup

Make sure Docker is running and the imputation pipeline is built:

```bash
# From the project root
docker-compose build
```

## Usage

1. **Upload**: Drag and drop or select a .txt genome file
2. **Process**: The file will be automatically processed through the Docker pipeline
3. **Monitor**: Real-time status updates show processing progress
4. **Download**: Download the processed results when complete

## Features

- ✅ File upload with drag & drop
- ✅ UUID-based file management
- ✅ Real-time status updates
- ✅ File validation (.txt only, max 1GB)
- ✅ Automatic processing through Docker
- ✅ Download processed results
- ✅ Job history tracking

## API Endpoints

- `POST /api/upload` - Upload a file
- `POST /api/process/{uuid}` - Start processing
- `GET /api/status/{uuid}` - Check job status
- `GET /api/download/{uuid}` - Download results
- `GET /api/files` - List all jobs
- `WS /ws/{uuid}` - WebSocket for real-time updates

## File Flow

1. User uploads file → Saved as `/uploads/{uuid}.txt`
2. FastAPI triggers Docker processing
3. Docker processes file → Output to `/results/{uuid}/`
4. User downloads processed file

## Development

- Backend: FastAPI with async file handling
- Frontend: React with axios for API calls
- Real-time: WebSocket for status updates
- Storage: Local file system with UUID-based organization 