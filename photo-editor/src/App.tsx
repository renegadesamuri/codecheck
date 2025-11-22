import { useState, useRef, useCallback } from 'react'
import { Upload, Download, RotateCw, Crop, Zap, Image as ImageIcon, Type, Square, PenTool, Wand2, Layers } from 'lucide-react'
import { Canvas } from './components/Canvas'
import { Toolbar } from './components/Toolbar'
import { Sidebar } from './components/Sidebar'
import { ImageUpload } from './components/ImageUpload'
import { useImageEditor } from './hooks/useImageEditor'
import './App.css'

function App() {
  const [isImageLoaded, setIsImageLoaded] = useState(false)
  const [activeTool, setActiveTool] = useState<string>('select')
  const [sidebarOpen, setSidebarOpen] = useState(true)
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
    addText,
    addShape,
    toggleDrawingMode,
    autoEnhance,
    canUndo,
    canRedo
  } = useImageEditor()

  const handleImageUpload = useCallback((file: File) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      const img = new Image()
      img.crossOrigin = 'anonymous'
      img.onload = () => {
        // Wait for canvas
        const waitForCanvas = () => {
          if (canvasRef.current) {
            loadImage(img)
            setIsImageLoaded(true)
          } else {
            setTimeout(waitForCanvas, 100)
          }
        }
        waitForCanvas()
      }
      img.src = e.target?.result as string
    }
    reader.readAsDataURL(file)
  }, [loadImage])

  const handleExport = useCallback(() => {
    exportImage('png')
  }, [exportImage])

  const tools = [
    { id: 'select', icon: 'cursor', label: 'Select' },
    { id: 'enhance', icon: Wand2, label: 'AI Enhance' },
    { id: 'text', icon: Type, label: 'Text' },
    { id: 'shapes', icon: Square, label: 'Shapes' },
    { id: 'draw', icon: PenTool, label: 'Draw' },
    { id: 'crop', icon: Crop, label: 'Crop' },
    { id: 'rotate', icon: RotateCw, label: 'Rotate' },
    { id: 'brightness', icon: Zap, label: 'Adjust' },
    { id: 'filters', icon: ImageIcon, label: 'Filters' }
  ]

  const handleToolSelect = (toolId: string) => {
    setActiveTool(toolId)
    setSidebarOpen(true)
    
    if (toolId === 'enhance') {
      autoEnhance()
    }
  }

  return (
    <div className="app">
      {/* Header */}
      <header className="app-header glass">
        <div className="header-content">
          <div className="logo">
            <div style={{ background: 'linear-gradient(135deg, #6366f1, #a855f7)', padding: '8px', borderRadius: '8px' }}>
              <Layers size={24} color="white" />
            </div>
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
              <Upload size={18} />
              Upload
            </button>
            
            {isImageLoaded && (
              <button
                className="btn btn-secondary"
                onClick={handleExport}
              >
                <Download size={18} />
                Export
              </button>
            )}
          </div>
        </div>
      </header>

      <div className="app-body">
        <div className="main-content">
          {/* Toolbar */}
          <Toolbar
            tools={tools}
            activeTool={activeTool}
            onToolSelect={handleToolSelect}
            onUndo={undo}
            onRedo={redo}
            canUndo={canUndo}
            canRedo={canRedo}
            onReset={resetImage}
          />

          {/* Canvas Area */}
          <div className="canvas-container">
            {!isImageLoaded ? (
              <div className="loading-container">
                <ImageUpload onImageUpload={handleImageUpload} />
              </div>
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
              onAddText={addText}
              onAddShape={addShape}
              onToggleDrawing={toggleDrawingMode}
            />
          )}
        </div>
      </div>
    </div>
  )
}

export default App