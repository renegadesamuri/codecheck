import React, { useState } from 'react'
import { X, Palette, Zap, Image as ImageIcon, RotateCw, Crop, Square, PenTool } from 'lucide-react'
import { TextTool } from './TextTool'
import './Sidebar.css'

interface SidebarProps {
  isOpen: boolean
  onToggle: () => void
  activeTool: string
  onAdjustBrightness: (value: number) => void
  onAdjustContrast: (value: number) => void
  onAdjustSaturation: (value: number) => void
  onApplyFilter: (filter: string) => void
  onRotate: (angle: number) => void
  onCrop: () => void
  onAddText: (text: string, options: any) => void
  onAddShape: (shape: 'rect' | 'circle' | 'triangle') => void
  onToggleDrawing: (isDrawing: boolean, color?: string, width?: number) => void
}

export const Sidebar: React.FC<SidebarProps> = ({
  isOpen,
  onToggle,
  activeTool,
  onAdjustBrightness,
  onAdjustContrast,
  onAdjustSaturation,
  onApplyFilter,
  onRotate,
  onCrop,
  onAddText,
  onAddShape,
  onToggleDrawing
}) => {
  const [brightness, setBrightness] = useState(0)
  const [contrast, setContrast] = useState(0)
  const [saturation, setSaturation] = useState(0)
  const [drawingColor, setDrawingColor] = useState('#ffffff')
  const [drawingWidth, setDrawingWidth] = useState(5)

  const filters = [
    { id: 'grayscale', name: 'Grayscale', icon: '⚫' },
    { id: 'sepia', name: 'Sepia', icon: '🟤' },
    { id: 'vintage', name: 'Vintage', icon: '📷' },
    { id: 'blur', name: 'Blur', icon: '🌫️' },
    { id: 'sharpen', name: 'Sharpen', icon: '✨' },
    { id: 'invert', name: 'Invert', icon: '🔄' }
  ]

  const handleBrightnessChange = (value: number) => {
    setBrightness(value)
    onAdjustBrightness(value)
  }

  const handleContrastChange = (value: number) => {
    setContrast(value)
    onAdjustContrast(value)
  }

  const handleSaturationChange = (value: number) => {
    setSaturation(value)
    onAdjustSaturation(value)
  }

  const handleFilterApply = (filterId: string) => {
    onApplyFilter(filterId)
  }

  const handleRotate = (angle: number) => {
    onRotate(angle)
  }

  const handleDrawingChange = (color: string, width: number) => {
    setDrawingColor(color)
    setDrawingWidth(width)
    onToggleDrawing(true, color, width)
  }

  // Effect to toggle drawing mode based on active tool
  React.useEffect(() => {
    if (activeTool === 'draw') {
      onToggleDrawing(true, drawingColor, drawingWidth)
    } else {
      onToggleDrawing(false)
    }
  }, [activeTool, onToggleDrawing, drawingColor, drawingWidth])

  if (!isOpen) {
    return (
      <button
        className="sidebar-toggle"
        onClick={onToggle}
        title="Open Sidebar"
      >
        <Palette size={20} />
      </button>
    )
  }

  return (
    <div className="sidebar glass">
      <div className="sidebar-header">
        <h3>Edit Controls</h3>
        <button
          className="btn btn-ghost"
          onClick={onToggle}
          title="Close Sidebar"
        >
          <X size={16} />
        </button>
      </div>

      <div className="sidebar-content">
        {/* Text Tool */}
        {activeTool === 'text' && (
          <TextTool onAddText={onAddText} />
        )}

        {/* Shapes Tool */}
        {activeTool === 'shapes' && (
          <div className="control-group">
            <label className="control-label">
              <Square size={16} />
              Add Shape
            </label>
            <div className="shape-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
              <button className="btn btn-secondary" onClick={() => onAddShape('rect')}>
                Rectangle
              </button>
              <button className="btn btn-secondary" onClick={() => onAddShape('circle')}>
                Circle
              </button>
              <button className="btn btn-secondary" onClick={() => onAddShape('triangle')}>
                Triangle
              </button>
            </div>
          </div>
        )}

        {/* Drawing Tool */}
        {activeTool === 'draw' && (
          <div className="control-group">
            <label className="control-label">
              <PenTool size={16} />
              Drawing Settings
            </label>
            <div className="input-group">
              <label className="label">Color</label>
              <input
                type="color"
                value={drawingColor}
                onChange={(e) => handleDrawingChange(e.target.value, drawingWidth)}
                style={{ width: '100%', height: '40px', borderRadius: '8px', border: 'none', cursor: 'pointer' }}
              />
            </div>
            <div className="input-group">
              <label className="label">Brush Size: {drawingWidth}px</label>
              <input
                type="range"
                min="1"
                max="50"
                value={drawingWidth}
                onChange={(e) => handleDrawingChange(drawingColor, Number(e.target.value))}
                className="slider"
              />
            </div>
          </div>
        )}

        {/* Standard Adjustments (Always visible or only when specific tools selected? 
            Let's keep them visible for 'brightness', 'contrast', 'saturation', 'filters' or default) 
        */}
        
        {(activeTool === 'brightness' || activeTool === 'select') && (
          <div className="control-group">
            <label className="control-label">
              <Zap size={16} />
              Brightness
            </label>
            <div className="slider-container">
              <input
                type="range"
                min="-100"
                max="100"
                value={brightness}
                onChange={(e) => handleBrightnessChange(Number(e.target.value))}
                className="slider"
              />
              <span className="slider-value">{brightness}%</span>
            </div>
          </div>
        )}

        {(activeTool === 'contrast' || activeTool === 'select') && (
          <div className="control-group">
            <label className="control-label">
              <Palette size={16} />
              Contrast
            </label>
            <div className="slider-container">
              <input
                type="range"
                min="-100"
                max="100"
                value={contrast}
                onChange={(e) => handleContrastChange(Number(e.target.value))}
                className="slider"
              />
              <span className="slider-value">{contrast}%</span>
            </div>
          </div>
        )}

        {(activeTool === 'saturation' || activeTool === 'select') && (
          <div className="control-group">
            <label className="control-label">
              <Palette size={16} />
              Saturation
            </label>
            <div className="slider-container">
              <input
                type="range"
                min="-100"
                max="100"
                value={saturation}
                onChange={(e) => handleSaturationChange(Number(e.target.value))}
                className="slider"
              />
              <span className="slider-value">{saturation}%</span>
            </div>
          </div>
        )}

        {/* Filters */}
        {(activeTool === 'filters' || activeTool === 'select') && (
          <div className="control-group">
            <label className="control-label">
              <ImageIcon size={16} />
              Filters
            </label>
            <div className="filter-grid">
              {filters.map((filter) => (
                <button
                  key={filter.id}
                  className="filter-btn"
                  onClick={() => handleFilterApply(filter.id)}
                  title={filter.name}
                >
                  <span className="filter-icon">{filter.icon}</span>
                  <span className="filter-name">{filter.name}</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Rotation Controls */}
        {(activeTool === 'rotate' || activeTool === 'select') && (
          <div className="control-group">
            <label className="control-label">
              <RotateCw size={16} />
              Rotation
            </label>
            <div className="rotation-controls">
              <button
                className="btn btn-secondary"
                onClick={() => handleRotate(-90)}
              >
                ↺ 90°
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => handleRotate(90)}
              >
                ↻ 90°
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => handleRotate(180)}
              >
                ↻ 180°
              </button>
            </div>
          </div>
        )}

        {/* Crop Action */}
        {activeTool === 'crop' && (
          <div className="control-group">
            <button
              className="btn btn-primary"
              onClick={onCrop}
              style={{ width: '100%' }}
            >
              <Crop size={16} />
              Apply Crop
            </button>
          </div>
        )}
      </div>
    </div>
  )
}