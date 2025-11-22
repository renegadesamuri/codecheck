import React, { useCallback, useState } from 'react'
import { Upload, Image as ImageIcon, FileImage } from 'lucide-react'
import './ImageUpload.css'

interface ImageUploadProps {
  onImageUpload: (file: File) => void
}

export const ImageUpload: React.FC<ImageUploadProps> = ({ onImageUpload }) => {
  const [isDragOver, setIsDragOver] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const handleFileSelect = useCallback((file: File) => {
    console.log('File selected:', file.name, file.type, file.size)
    
    if (!file.type.startsWith('image/')) {
      alert('Please select a valid image file')
      return
    }

    setIsLoading(true)
    onImageUpload(file)
    // Remove the timeout - let the actual loading control the state
  }, [onImageUpload])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)

    const files = Array.from(e.dataTransfer.files)
    if (files.length > 0) {
      handleFileSelect(files[0])
    }
  }, [handleFileSelect])

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
  }, [])

  const handleFileInputChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      handleFileSelect(file)
    }
  }, [handleFileSelect])

  return (
    <div className="image-upload-container">
      <div
        className={`upload-area ${isDragOver ? 'drag-over' : ''} ${isLoading ? 'loading' : ''}`}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
      >
        <input
          type="file"
          accept="image/*"
          onChange={handleFileInputChange}
          style={{ display: 'none' }}
          id="file-input"
        />
        
        <label htmlFor="file-input" className="upload-label">
          {isLoading ? (
            <div className="loading-content">
              <div className="loading-spinner"></div>
              <p>Processing image...</p>
            </div>
          ) : (
            <div className="upload-content">
              <div className="upload-icon">
                <Upload size={48} />
              </div>
              <h3>Upload Your Image</h3>
              <p>Drag and drop an image here, or click to browse</p>
              <div className="supported-formats">
                <span>Supports: JPG, PNG, GIF, WebP</span>
              </div>
            </div>
          )}
        </label>
      </div>

      <div className="upload-features">
        <div className="feature">
          <ImageIcon size={20} />
          <span>High-quality editing</span>
        </div>
        <div className="feature">
          <FileImage size={20} />
          <span>Multiple formats</span>
        </div>
        <div className="feature">
          <Upload size={20} />
          <span>Easy export</span>
        </div>
      </div>
    </div>
  )
}