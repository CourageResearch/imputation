import os
import uuid
import json
import asyncio
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List

from fastapi import FastAPI, File, UploadFile, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import aiofiles

app = FastAPI(title="Genome Imputation API", version="1.0.0")

# CORS middleware for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# File storage paths
UPLOAD_DIR = Path("../uploads")
RESULTS_DIR = Path("../results")
MAX_FILE_SIZE = 1024 * 1024 * 1024  # 1GB

# Ensure directories exist
UPLOAD_DIR.mkdir(exist_ok=True)
RESULTS_DIR.mkdir(exist_ok=True)

# In-memory job tracking (in production, use a database)
jobs: Dict[str, Dict] = {}

class JobStatus(BaseModel):
    uuid: str
    status: str
    original_filename: str
    uploaded_at: str
    started_at: str = None
    completed_at: str = None
    error: str = None

@app.get("/")
async def root():
    return {"message": "Genome Imputation API"}

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    """Upload a genome file and return a UUID for processing"""
    
    # Validate file type
    if not file.filename.endswith('.txt'):
        raise HTTPException(status_code=400, detail="Only .txt files are allowed")
    
    # Generate UUID
    job_uuid = str(uuid.uuid4())
    
    # Save file
    file_path = UPLOAD_DIR / f"{job_uuid}.txt"
    async with aiofiles.open(file_path, 'wb') as f:
        content = await file.read()
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(status_code=413, detail="File too large (max 1GB)")
        await f.write(content)
    
    # Create job record
    jobs[job_uuid] = {
        "uuid": job_uuid,
        "status": "uploaded",
        "original_filename": file.filename,
        "uploaded_at": datetime.now().isoformat(),
        "file_path": str(file_path),
        "results_path": str(RESULTS_DIR / job_uuid)
    }
    
    return {"uuid": job_uuid, "filename": file.filename}

@app.post("/api/process/{job_uuid}")
async def process_file(job_uuid: str):
    """Start processing a file with the given UUID"""
    
    if job_uuid not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[job_uuid]
    if job["status"] != "uploaded":
        raise HTTPException(status_code=400, detail=f"Job status is {job['status']}, cannot process")
    
    # Update job status
    job["status"] = "processing"
    job["started_at"] = datetime.now().isoformat()
    
    # Start processing in background
    asyncio.create_task(run_docker_processing(job_uuid))
    
    return {"message": "Processing started", "uuid": job_uuid}

async def run_docker_processing(job_uuid: str):
    """Run the Docker container to process the file"""
    try:
        job = jobs[job_uuid]
        
        # Create results directory
        results_path = RESULTS_DIR / job_uuid
        results_path.mkdir(exist_ok=True)
        
        # Run Docker command
        cmd = [
            "docker-compose", "run", "--rm",
            "-e", f"JOB_UUID={job_uuid}",
            "-v", f"{UPLOAD_DIR}:/imputation/uploads",
            "-v", f"{results_path}:/imputation/results",
            "imputation"
        ]
        
        # Execute Docker command
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode == 0:
            job["status"] = "completed"
            job["completed_at"] = datetime.now().isoformat()
        else:
            job["status"] = "error"
            job["error"] = f"STDOUT: {stdout.decode()}\nSTDERR: {stderr.decode()}"
            print(f"DOCKER ERROR (UUID: {job_uuid}):\nSTDOUT:\n{stdout.decode()}\nSTDERR:\n{stderr.decode()}")
            
    except Exception as e:
        job["status"] = "error"
        job["error"] = str(e)

@app.get("/api/status/{job_uuid}")
async def get_status(job_uuid: str):
    """Get the status of a job"""
    
    if job_uuid not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return jobs[job_uuid]

@app.get("/api/files")
async def list_files():
    """List all uploaded files"""
    return {"jobs": list(jobs.values())}

@app.get("/api/download/{job_uuid}")
async def download_results(job_uuid: str):
    """Download the processed results"""
    
    if job_uuid not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[job_uuid]
    if job["status"] != "completed":
        raise HTTPException(status_code=400, detail=f"Job not completed (status: {job['status']})")
    
    results_path = RESULTS_DIR / job_uuid
    output_file = results_path / f"{job_uuid}.txt.gz"
    
    if not output_file.exists():
        raise HTTPException(status_code=404, detail="Output file not found")
    
    return FileResponse(
        path=output_file,
        filename=f"{job['original_filename']}.processed.gz",
        media_type="application/gzip"
    )

@app.websocket("/ws/{job_uuid}")
async def websocket_endpoint(websocket: WebSocket, job_uuid: str):
    """WebSocket endpoint for real-time status updates"""
    await websocket.accept()
    
    try:
        while True:
            if job_uuid in jobs:
                await websocket.send_text(json.dumps(jobs[job_uuid]))
            await asyncio.sleep(1)
    except WebSocketDisconnect:
        pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 