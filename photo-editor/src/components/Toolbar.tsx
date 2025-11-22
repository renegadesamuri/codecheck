import React from 'react'
import { Undo2, Redo2, RotateCcw } from 'lucide-react'
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
  const renderIcon = (icon: React.ComponentType<any> | string, size: number = 20) => {
    if (typeof icon === 'string') {
      return <span className="icon-text" style={{ fontSize: '20px' }}>{icon}</span>
    }
    const IconComponent = icon
    return <IconComponent size={size} />
  }

  return (
    <div className="toolbar glass">
      <div className="toolbar-section">
        <h3 className="section-title">Tools</h3>
        <div className="tool-grid">
          {tools.map((tool) => (
            <button
              key={tool.id}
              className={`tool-btn ${activeTool === tool.id ? 'active' : ''}`}
              onClick={() => onToolSelect(tool.id)}
              title={tool.label}
            >
              <div className="tool-icon">
                {renderIcon(tool.icon)}
              </div>
              <span className="tool-label">{tool.label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="toolbar-separator"></div>

      <div className="toolbar-section">
        <h3 className="section-title">History</h3>
        <div className="actions-row">
          <button
            className="action-btn"
            onClick={onUndo}
            disabled={!canUndo}
            title="Undo"
          >
            <Undo2 size={20} />
          </button>
          
          <button
            className="action-btn"
            onClick={onRedo}
            disabled={!canRedo}
            title="Redo"
          >
            <Redo2 size={20} />
          </button>
          
          <button
            className="action-btn danger"
            onClick={onReset}
            title="Reset Image"
          >
            <RotateCcw size={20} />
          </button>
        </div>
      </div>
    </div>
  )
}