import React, { useState, useRef, useCallback } from 'react'
import { Upload, Download, RotateCw, Crop, Palette, Zap, Settings, Image as ImageIcon } from 'lucide-react'
import { Canvas } from './components/Canvas'
import { Toolbar } from './components/Toolbar'
import { Sidebar } from './components/Sidebar'
import { ImageUpload } from './components/ImageUpload'
import { useImageEditor } from './hooks/useImageEditor'
import './App.css'

function App() {
  const [isImageLoaded, setIsImageLoaded] = useState(false)
  const [activeTool, setActiveTool] = useState<string>('select')
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const {
    canvasRef,
    loadImage,
    exportImage,
    applyFilter,
    adjustBrightness,
    adjustContrast,
    adjustSaturation,
    rotateImage,
    cropImage,
    resetImage,
    undo,
    redo,
    canUndo,
    canRedo
  } = useImageEditor()

  const handleImageUpload = useCallback((file: File) => {
    console.log('Starting image upload for:', file.name)
    const reader = new FileReader()
    reader.onload = (e) => {
      console.log('File read successfully, creating image...')
      const img = new Image()
      img.crossOrigin = 'anonymous' // Handle CORS if needed
      img.onload = () => {
        console.log('Image loaded successfully, dimensions:', img.naturalWidth, 'x', img.naturalHeight)
        
        // Wait for canvas to be ready
        let attempts = 0
        const maxAttempts = 50 // 5 seconds max wait
        const waitForCanvas = () => {
          attempts++
          if (canvasRef.current) {
            console.log('Canvas is ready, loading image...')
            loadImage(img)
            setIsImageLoaded(true)
          } else if (attempts < maxAttempts) {
            console.log(`Canvas not ready yet, waiting... (attempt ${attempts}/${maxAttempts})`)
            setTimeout(waitForCanvas, 100)
          } else {
            console.error('Canvas failed to initialize after 5 seconds')
            alert('Failed to initialize canvas. Please refresh the page and try again.')
          }
        }
        waitForCanvas()
      }
      img.onerror = (error) => {
        console.error('Failed to load image:', error)
        alert('Failed to load image. Please try a different file.')
      }
      img.src = e.target?.result as string
    }
    reader.onerror = (error) => {
      console.error('Failed to read file:', error)
      alert('Failed to read file. Please try again.')
    }
    reader.readAsDataURL(file)
  }, [loadImage])

  const handleExport = useCallback(() => {
    exportImage('png')
  }, [exportImage])

  const tools = [
    { id: 'select', icon: 'cursor', label: 'Select' },
    { id: 'crop', icon: Crop, label: 'Crop' },
    { id: 'rotate', icon: RotateCw, label: 'Rotate' },
    { id: 'brightness', icon: Zap, label: 'Brightness' },
    { id: 'contrast', icon: Palette, label: 'Contrast' },
    { id: 'saturation', icon: Palette, label: 'Saturation' },
    { id: 'filters', icon: ImageIcon, label: 'Filters' }
  ]

  return (
    <div className="app">
      {/* Header */}
      <header className="app-header glass">
        <div className="header-content">
          <div className="logo">
            <ImageIcon size={24} />
            <h1>Photo Editor Pro</h1>
          </div>
          
          <div className="header-actions">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) handleImageUpload(file)
              }}
              style={{ display: 'none' }}
            />
            
            <button
              className="btn btn-primary"
              onClick={() => fileInputRef.current?.click()}
            >
              <Upload size={16} />
              Upload Image
            </button>
            
            {isImageLoaded && (
              <button
                className="btn btn-secondary"
                onClick={handleExport}
              >
                <Download size={16} />
                Export
              </button>
            )}
          </div>
        </div>
      </header>

      <div className="app-body">
        {/* Toolbar */}
        <Toolbar
          tools={tools}
          activeTool={activeTool}
          onToolSelect={setActiveTool}
          onUndo={undo}
          onRedo={redo}
          canUndo={canUndo}
          canRedo={canRedo}
          onReset={resetImage}
        />

        {/* Main Content */}
        <div className="main-content">
          {/* Canvas Area */}
          <div className="canvas-container">
            {!isImageLoaded ? (
              <ImageUpload onImageUpload={handleImageUpload} />
            ) : (
              <Canvas
                ref={canvasRef}
                activeTool={activeTool}
                onToolChange={setActiveTool}
              />
            )}
          </div>

          {/* Sidebar */}
          {isImageLoaded && (
            <Sidebar
              isOpen={sidebarOpen}
              onToggle={() => setSidebarOpen(!sidebarOpen)}
              activeTool={activeTool}
              onAdjustBrightness={adjustBrightness}
              onAdjustContrast={adjustContrast}
              onAdjustSaturation={adjustSaturation}
              onApplyFilter={applyFilter}
              onRotate={rotateImage}
              onCrop={cropImage}
            />
          )}
        </div>
      </div>
    </div>
  )
}

export default App