import React, { useState } from 'react'
import { Type, Plus } from 'lucide-react'

interface TextToolProps {
  onAddText: (text: string, options: any) => void
}

export const TextTool: React.FC<TextToolProps> = ({ onAddText }) => {
  const [text, setText] = useState('Hello World')
  const [color, setColor] = useState('#ffffff')
  const [fontSize, setFontSize] = useState(40)
  const [fontFamily, setFontFamily] = useState('Outfit')

  const handleAddText = () => {
    onAddText(text, {
      fill: color,
      fontSize,
      fontFamily
    })
  }

  return (
    <div className="control-group">
      <label className="control-label">
        <Type size={16} />
        Add Text
      </label>
      
      <div className="input-group">
        <input
          type="text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          className="input glass"
          placeholder="Enter text..."
          style={{ 
            width: '100%', 
            padding: '8px 12px', 
            marginBottom: '12px',
            background: 'rgba(255,255,255,0.1)',
            border: '1px solid rgba(255,255,255,0.2)',
            borderRadius: '8px',
            color: 'white'
          }}
        />
      </div>

      <div className="input-group" style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
        <input
          type="color"
          value={color}
          onChange={(e) => setColor(e.target.value)}
          style={{ 
            width: '40px', 
            height: '40px', 
            border: 'none', 
            borderRadius: '8px', 
            cursor: 'pointer',
            background: 'transparent'
          }}
        />
        <input
          type="number"
          value={fontSize}
          onChange={(e) => setFontSize(Number(e.target.value))}
          className="input glass"
          style={{ 
            flex: 1,
            padding: '8px',
            background: 'rgba(255,255,255,0.1)',
            border: '1px solid rgba(255,255,255,0.2)',
            borderRadius: '8px',
            color: 'white'
          }}
        />
      </div>

      <div className="input-group" style={{ marginBottom: '16px' }}>
        <select
          value={fontFamily}
          onChange={(e) => setFontFamily(e.target.value)}
          className="input glass"
          style={{ 
            width: '100%', 
            padding: '8px',
            background: 'rgba(255,255,255,0.1)',
            border: '1px solid rgba(255,255,255,0.2)',
            borderRadius: '8px',
            color: 'white'
          }}
        >
          <option value="Outfit">Outfit</option>
          <option value="Inter">Inter</option>
          <option value="Arial">Arial</option>
          <option value="Times New Roman">Times New Roman</option>
          <option value="Courier New">Courier New</option>
        </select>
      </div>

      <button
        className="btn btn-primary"
        onClick={handleAddText}
        style={{ width: '100%' }}
      >
        <Plus size={16} />
        Add to Canvas
      </button>
    </div>
  )
}
