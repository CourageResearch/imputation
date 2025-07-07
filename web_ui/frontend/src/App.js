import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [selectedFile, setSelectedFile] = useState(null);
  const [isDragging, setIsDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [currentJob, setCurrentJob] = useState(null);
  const [jobs, setJobs] = useState([]);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Load existing jobs on component mount
  useEffect(() => {
    loadJobs();
  }, []);

  // Poll for job status updates
  useEffect(() => {
    if (currentJob && currentJob.status !== 'completed' && currentJob.status !== 'error') {
      const interval = setInterval(() => {
        checkJobStatus(currentJob.uuid);
      }, 2000);
      return () => clearInterval(interval);
    }
  }, [currentJob]);

  const loadJobs = async () => {
    try {
      const response = await axios.get('/api/files');
      setJobs(response.data.jobs || []);
    } catch (err) {
      console.error('Error loading jobs:', err);
    }
  };

  const checkJobStatus = async (uuid) => {
    try {
      const response = await axios.get(`/api/status/${uuid}`);
      const updatedJob = response.data;
      
      setCurrentJob(updatedJob);
      setJobs(prevJobs => 
        prevJobs.map(job => 
          job.uuid === uuid ? updatedJob : job
        )
      );

      if (updatedJob.status === 'completed') {
        setSuccess('Processing completed! You can now download your results.');
      } else if (updatedJob.status === 'error') {
        setError(`Processing failed: ${updatedJob.error}`);
      }
    } catch (err) {
      console.error('Error checking job status:', err);
    }
  };

  const handleFileSelect = (event) => {
    const file = event.target.files[0];
    if (file && file.name.endsWith('.txt')) {
      setSelectedFile(file);
      setError('');
    } else {
      setError('Please select a .txt file');
      setSelectedFile(null);
    }
  };

  const handleDragOver = (event) => {
    event.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (event) => {
    event.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (event) => {
    event.preventDefault();
    setIsDragging(false);
    
    const file = event.dataTransfer.files[0];
    if (file && file.name.endsWith('.txt')) {
      setSelectedFile(file);
      setError('');
    } else {
      setError('Please drop a .txt file');
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      setError('Please select a file first');
      return;
    }

    setUploading(true);
    setError('');
    setSuccess('');

    try {
      const formData = new FormData();
      formData.append('file', selectedFile);

      const response = await axios.post('/api/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      const { uuid, filename } = response.data;
      setSuccess(`File uploaded successfully! UUID: ${uuid}`);
      
      // Start processing
      await axios.post(`/api/process/${uuid}`);
      
      // Set as current job and start monitoring
      const jobData = {
        uuid,
        status: 'processing',
        original_filename: filename,
        uploaded_at: new Date().toISOString(),
      };
      
      setCurrentJob(jobData);
      setJobs(prevJobs => [jobData, ...prevJobs]);
      setSelectedFile(null);
      
    } catch (err) {
      setError(err.response?.data?.detail || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const handleDownload = async (uuid, filename) => {
    try {
      const response = await axios.get(`/api/download/${uuid}`, {
        responseType: 'blob',
      });
      
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `${filename}.processed.gz`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      setError('Download failed');
    }
  };

  const getStatusBadgeClass = (status) => {
    switch (status) {
      case 'uploaded': return 'status-uploaded';
      case 'processing': return 'status-processing';
      case 'completed': return 'status-completed';
      case 'error': return 'status-error';
      default: return '';
    }
  };

  return (
    <div className="container">
      <div className="header">
        <h1>Genome Imputation Pipeline</h1>
        <p>Upload your genome file and get processed results</p>
      </div>

      {error && <div className="error-message">{error}</div>}
      {success && <div className="success-message">{success}</div>}

      <div className="upload-section">
        <h2>Upload Genome File</h2>
        <div
          className={`file-upload ${isDragging ? 'dragover' : ''}`}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onClick={() => document.getElementById('file-input').click()}
        >
          <input
            id="file-input"
            type="file"
            accept=".txt"
            onChange={handleFileSelect}
            style={{ display: 'none' }}
          />
          {selectedFile ? (
            <div>
              <p><strong>Selected file:</strong> {selectedFile.name}</p>
              <p>Size: {(selectedFile.size / 1024 / 1024).toFixed(2)} MB</p>
            </div>
          ) : (
            <div>
              <p>Click to select or drag and drop a .txt file</p>
              <p>Maximum file size: 1GB</p>
            </div>
          )}
        </div>
        <button
          className="upload-button"
          onClick={handleUpload}
          disabled={!selectedFile || uploading}
        >
          {uploading ? 'Uploading...' : 'Upload & Process'}
        </button>
      </div>

      {currentJob && (
        <div className="status-section">
          <h2>Current Job Status</h2>
          <div className="status-item">
            <div>
              <strong>File:</strong> {currentJob.original_filename}
            </div>
            <span className={`status-badge ${getStatusBadgeClass(currentJob.status)}`}>
              {currentJob.status}
            </span>
          </div>
          <div className="uuid-display">
            <strong>UUID:</strong> {currentJob.uuid}
          </div>
          {currentJob.status === 'completed' && (
            <button
              className="download-button"
              onClick={() => handleDownload(currentJob.uuid, currentJob.original_filename)}
            >
              Download Results
            </button>
          )}
        </div>
      )}

      {jobs.length > 0 && (
        <div className="status-section">
          <h2>All Jobs</h2>
          {jobs.map((job) => (
            <div key={job.uuid} className="status-item">
              <div>
                <strong>{job.original_filename}</strong>
                <br />
                <small>UUID: {job.uuid}</small>
              </div>
              <div>
                <span className={`status-badge ${getStatusBadgeClass(job.status)}`}>
                  {job.status}
                </span>
                {job.status === 'completed' && (
                  <button
                    className="download-button"
                    onClick={() => handleDownload(job.uuid, job.original_filename)}
                    style={{ marginLeft: '10px' }}
                  >
                    Download
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default App; 