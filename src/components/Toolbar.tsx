import React from 'react'
import { Undo2, Redo2, RotateCcw, Crop, RotateCw, Palette, Zap, Image as ImageIcon } from 'lucide-react'
import './Toolbar.css'

interface Tool {
  id: string
  icon: React.ComponentType<any> | string
  label: string
}

interface ToolbarProps {
  tools: Tool[]
  activeTool: string
  onToolSelect: (toolId: string) => void
  onUndo: () => void
  onRedo: () => void
  canUndo: boolean
  canRedo: boolean
  onReset: () => void
}

export const Toolbar: React.FC<ToolbarProps> = ({
  tools,
  activeTool,
  onToolSelect,
  onUndo,
  onRedo,
  canUndo,
  canRedo,
  onReset
}) => {
  const renderIcon = (icon: React.ComponentType<any> | string, size: number = 18) => {
    if (typeof icon === 'string') {
      return <span className="icon-text">{icon}</span>
    }
    const IconComponent = icon
    return <IconComponent size={size} />
  }

  return (
    <div className="toolbar glass">
      <div className="toolbar-section">
        <h3>Tools</h3>
        <div className="tool-group">
          {tools.map((tool) => (
            <button
              key={tool.id}
              className={`tool-btn ${activeTool === tool.id ? 'active' : ''}`}
              onClick={() => onToolSelect(tool.id)}
              title={tool.label}
            >
              {renderIcon(tool.icon)}
              <span className="tool-label">{tool.label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="toolbar-section">
        <h3>Actions</h3>
        <div className="tool-group">
          <button
            className="tool-btn"
            onClick={onUndo}
            disabled={!canUndo}
            title="Undo"
          >
            <Undo2 size={18} />
            <span className="tool-label">Undo</span>
          </button>
          
          <button
            className="tool-btn"
            onClick={onRedo}
            disabled={!canRedo}
            title="Redo"
          >
            <Redo2 size={18} />
            <span className="tool-label">Redo</span>
          </button>
          
          <button
            className="tool-btn"
            onClick={onReset}
            title="Reset Image"
          >
            <RotateCcw size={18} />
            <span className="tool-label">Reset</span>
          </button>
        </div>
      </div>

      <div className="toolbar-section">
        <h3>Quick Actions</h3>
        <div className="tool-group">
          <button
            className="tool-btn"
            onClick={() => onToolSelect('rotate')}
            title="Rotate 90°"
          >
            <RotateCw size={18} />
            <span className="tool-label">Rotate</span>
          </button>
          
          <button
            className="tool-btn"
            onClick={() => onToolSelect('crop')}
            title="Crop Image"
          >
            <Crop size={18} />
            <span className="tool-label">Crop</span>
          </button>
        </div>
      </div>
    </div>
  )
}