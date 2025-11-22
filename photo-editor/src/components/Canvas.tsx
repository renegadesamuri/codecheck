import { useEffect, useRef, forwardRef, useImperativeHandle } from 'react'
// @ts-ignore
import { fabric } from 'fabric'
import './Canvas.css'

interface CanvasProps {
  activeTool: string
  onToolChange: (tool: string) => void
}

export const Canvas = forwardRef<fabric.Canvas, CanvasProps>(({ activeTool, onToolChange }, ref) => {
  const canvasContainerRef = useRef<HTMLCanvasElement>(null)
  const canvasInstanceRef = useRef<fabric.Canvas | null>(null)

  useImperativeHandle(ref, () => canvasInstanceRef.current!, [])

  useEffect(() => {
    if (!canvasContainerRef.current) {
      console.log('Canvas container ref is null')
      return
    }

    console.log('Canvas useEffect triggered, container:', canvasContainerRef.current)

    // Wait for container to be properly sized
    const initializeCanvas = () => {
      const container = canvasContainerRef.current
      if (!container) {
        console.log('Container is null in initializeCanvas')
        return
      }

      const containerRect = container.getBoundingClientRect()
      console.log('Container rect:', containerRect)
      
      // Use fixed dimensions if container is too small
      const width = containerRect.width > 100 ? Math.min(800, containerRect.width - 40) : 600
      const height = containerRect.height > 100 ? Math.min(600, containerRect.height - 40) : 400

      console.log('Creating canvas with dimensions:', width, 'x', height)

      try {
        const canvas = new fabric.Canvas(canvasContainerRef.current, {
          width,
          height,
          backgroundColor: 'transparent',
          selection: true,
          preserveObjectStacking: true,
          imageSmoothingEnabled: true,
          imageSmoothingQuality: 'high'
        })

        canvasInstanceRef.current = canvas
        console.log('Canvas created successfully!', canvas)

        // Handle object selection
        canvas.on('selection:created', () => {
          onToolChange('select')
        })

        canvas.on('selection:updated', () => {
          onToolChange('select')
        })

        canvas.on('selection:cleared', () => {
          onToolChange('select')
        })

        // Handle mouse events for different tools
        canvas.on('mouse:down', (opt: any) => {
          if (activeTool === 'crop') {
            handleCropStart(opt)
          }
        })

        canvas.on('mouse:move', (opt: any) => {
          if (activeTool === 'crop') {
            handleCropMove(opt)
          }
        })

        canvas.on('mouse:up', () => {
          if (activeTool === 'crop') {
            handleCropEnd()
          }
        })
      } catch (error) {
        console.error('Error creating canvas:', error)
      }
    }

    // Try multiple times to ensure container is ready
    const tryInitialize = () => {
      if (canvasContainerRef.current && canvasContainerRef.current.getBoundingClientRect().width > 0) {
        initializeCanvas()
      } else {
        console.log('Container not ready, retrying...')
        setTimeout(tryInitialize, 50)
      }
    }

    tryInitialize()

    return () => {
      if (canvasInstanceRef.current) {
        canvasInstanceRef.current.dispose()
      }
    }
  }, [activeTool, onToolChange])

  const handleCropStart = (opt: fabric.IEvent) => {
    const canvas = canvasInstanceRef.current
    if (!canvas) return

    const pointer = canvas.getPointer(opt.e)
    const cropRect = new fabric.Rect({
      left: pointer.x,
      top: pointer.y,
      width: 0,
      height: 0,
      fill: 'rgba(255, 255, 255, 0.1)',
      stroke: '#667eea',
      strokeWidth: 2,
      strokeDashArray: [5, 5],
      selectable: false,
      evented: false
    })

    canvas.add(cropRect)
    canvas.setActiveObject(cropRect)
  }

  const handleCropMove = (opt: fabric.IEvent) => {
    const canvas = canvasInstanceRef.current
    if (!canvas) return

    const activeObject = canvas.getActiveObject() as fabric.Rect
    if (!activeObject || activeObject.type !== 'rect') return

    const pointer = canvas.getPointer(opt.e)
    const width = Math.abs(pointer.x - activeObject.left!)
    const height = Math.abs(pointer.y - activeObject.top!)

    activeObject.set({
      width,
      height
    })

    canvas.renderAll()
  }

  const handleCropEnd = () => {
    const canvas = canvasInstanceRef.current
    if (!canvas) return

    const activeObject = canvas.getActiveObject() as fabric.Rect
    if (!activeObject || activeObject.type !== 'rect') return

    // Remove the crop rectangle
    canvas.remove(activeObject)
    onToolChange('select')
  }

  return (
    <div className="canvas-wrapper">
      <canvas
        ref={canvasContainerRef}
        className="fabric-canvas"
        style={{
          borderRadius: '12px',
          boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)',
          background: 'rgba(255, 255, 255, 0.05)',
          border: '1px solid rgba(255, 255, 255, 0.1)'
        }}
      />
      
      {activeTool === 'crop' && (
        <div className="tool-hint">
          <p>Click and drag to select crop area</p>
        </div>
      )}
    </div>
  )
})

Canvas.displayName = 'Canvas'