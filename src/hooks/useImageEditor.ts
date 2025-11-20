import { useRef, useCallback, useState } from 'react'
import { fabric } from 'fabric'

export const useImageEditor = () => {
  const canvasRef = useRef<fabric.Canvas | null>(null)
  const [history, setHistory] = useState<string[]>([])
  const [historyIndex, setHistoryIndex] = useState(-1)

  const saveState = useCallback(() => {
    if (!canvasRef.current) return
    
    const state = JSON.stringify(canvasRef.current.toJSON())
    const newHistory = history.slice(0, historyIndex + 1)
    newHistory.push(state)
    
    // Limit history to 20 states
    if (newHistory.length > 20) {
      newHistory.shift()
    } else {
      setHistoryIndex(historyIndex + 1)
    }
    
    setHistory(newHistory)
  }, [history, historyIndex])

  const loadImage = useCallback((img: HTMLImageElement) => {
    console.log('loadImage called with canvas:', canvasRef.current)
    if (!canvasRef.current) {
      console.error('Canvas ref is null!')
      return
    }

    const canvas = canvasRef.current
    const canvasWidth = canvas.getWidth()
    const canvasHeight = canvas.getHeight()
    
    console.log('Canvas dimensions:', canvasWidth, 'x', canvasHeight)
    
    // Ensure image is loaded
    if (!img.complete || img.naturalWidth === 0) {
      console.log('Image not complete, waiting for load...')
      img.onload = () => loadImage(img)
      return
    }
    
    console.log('Image dimensions:', img.naturalWidth, 'x', img.naturalHeight)
    
    // Calculate scale to fit image in canvas
    const scaleX = canvasWidth / img.naturalWidth
    const scaleY = canvasHeight / img.naturalHeight
    const scale = Math.min(scaleX, scaleY, 1) // Don't scale up
    
    const scaledWidth = img.naturalWidth * scale
    const scaledHeight = img.naturalHeight * scale
    
    console.log('Calculated scale:', scale, 'Scaled dimensions:', scaledWidth, 'x', scaledHeight)
    
    // Center the image
    const left = (canvasWidth - scaledWidth) / 2
    const top = (canvasHeight - scaledHeight) / 2

    console.log('Image position:', left, top)

    const fabricImage = new fabric.Image(img, {
      left,
      top,
      scaleX: scale,
      scaleY: scale,
      selectable: true,
      evented: true
    })

    console.log('Fabric image created:', fabricImage)

    canvas.clear()
    canvas.add(fabricImage)
    canvas.setActiveObject(fabricImage)
    canvas.renderAll()
    
    console.log('Image added to canvas, objects count:', canvas.getObjects().length)
    
    saveState()
  }, [saveState])

  const exportImage = useCallback((format: 'png' | 'jpeg' = 'png') => {
    if (!canvasRef.current) return

    const link = document.createElement('a')
    link.download = `edited-image.${format}`
    link.href = canvasRef.current.toDataURL({
      format,
      quality: 0.9,
      multiplier: 2 // High resolution export
    })
    link.click()
  }, [])

  const applyFilter = useCallback((filterType: string) => {
    if (!canvasRef.current) return

    const activeObject = canvasRef.current.getActiveObject() as fabric.Image
    if (!activeObject || !activeObject.filters) return

    // Remove existing filters
    activeObject.filters = []

    switch (filterType) {
      case 'grayscale':
        activeObject.filters.push(new fabric.Image.filters.Grayscale())
        break
      case 'sepia':
        activeObject.filters.push(new fabric.Image.filters.Sepia())
        break
      case 'vintage':
        activeObject.filters.push(new fabric.Image.filters.Vintage())
        break
      case 'blur':
        activeObject.filters.push(new fabric.Image.filters.Blur({ blur: 0.1 }))
        break
      case 'sharpen':
        activeObject.filters.push(new fabric.Image.filters.Convolute({
          matrix: [0, -1, 0, -1, 5, -1, 0, -1, 0]
        }))
        break
      case 'invert':
        activeObject.filters.push(new fabric.Image.filters.Invert())
        break
    }

    activeObject.applyFilters()
    canvasRef.current.renderAll()
    saveState()
  }, [saveState])

  const adjustBrightness = useCallback((value: number) => {
    if (!canvasRef.current) return

    const activeObject = canvasRef.current.getActiveObject() as fabric.Image
    if (!activeObject || !activeObject.filters) return

    // Remove existing brightness filter
    activeObject.filters = activeObject.filters.filter(
      filter => !(filter instanceof fabric.Image.filters.Brightness)
    )

    // Add new brightness filter
    activeObject.filters.push(new fabric.Image.filters.Brightness({
      brightness: value / 100
    }))

    activeObject.applyFilters()
    canvasRef.current.renderAll()
  }, [])

  const adjustContrast = useCallback((value: number) => {
    if (!canvasRef.current) return

    const activeObject = canvasRef.current.getActiveObject() as fabric.Image
    if (!activeObject || !activeObject.filters) return

    // Remove existing contrast filter
    activeObject.filters = activeObject.filters.filter(
      filter => !(filter instanceof fabric.Image.filters.Contrast)
    )

    // Add new contrast filter
    activeObject.filters.push(new fabric.Image.filters.Contrast({
      contrast: value / 100
    }))

    activeObject.applyFilters()
    canvasRef.current.renderAll()
  }, [])

  const adjustSaturation = useCallback((value: number) => {
    if (!canvasRef.current) return

    const activeObject = canvasRef.current.getActiveObject() as fabric.Image
    if (!activeObject || !activeObject.filters) return

    // Remove existing saturation filter
    activeObject.filters = activeObject.filters.filter(
      filter => !(filter instanceof fabric.Image.filters.Saturation)
    )

    // Add new saturation filter
    activeObject.filters.push(new fabric.Image.filters.Saturation({
      saturation: value / 100
    }))

    activeObject.applyFilters()
    canvasRef.current.renderAll()
  }, [])

  const rotateImage = useCallback((angle: number = 90) => {
    if (!canvasRef.current) return

    const activeObject = canvasRef.current.getActiveObject()
    if (!activeObject) return

    activeObject.rotate((activeObject.angle || 0) + angle)
    canvasRef.current.renderAll()
    saveState()
  }, [saveState])

  const cropImage = useCallback(() => {
    if (!canvasRef.current) return

    const canvas = canvasRef.current
    const activeObject = canvas.getActiveObject()
    
    if (!activeObject) return

    // Get the bounding box of the selected object
    const boundingRect = activeObject.getBoundingRect()
    
    // Create a new canvas with the cropped dimensions
    const croppedCanvas = document.createElement('canvas')
    const ctx = croppedCanvas.getContext('2d')
    
    if (!ctx) return

    croppedCanvas.width = boundingRect.width
    croppedCanvas.height = boundingRect.height

    // Draw the cropped image
    canvas.renderAll()
    const dataURL = canvas.toDataURL({
      left: boundingRect.left,
      top: boundingRect.top,
      width: boundingRect.width,
      height: boundingRect.height
    })

    const img = new Image()
    img.onload = () => {
      loadImage(img)
    }
    img.src = dataURL
  }, [loadImage])

  const resetImage = useCallback(() => {
    if (!canvasRef.current) return

    const canvas = canvasRef.current
    const objects = canvas.getObjects()
    
    if (objects.length > 0) {
      const originalImage = objects[0] as fabric.Image
      if (originalImage) {
        // Reset transformations
        originalImage.set({
          angle: 0,
          scaleX: 1,
          scaleY: 1,
          left: originalImage.left,
          top: originalImage.top,
          filters: []
        })
        
        originalImage.applyFilters()
        canvas.renderAll()
        saveState()
      }
    }
  }, [saveState])

  const undo = useCallback(() => {
    if (historyIndex > 0 && canvasRef.current) {
      const newIndex = historyIndex - 1
      setHistoryIndex(newIndex)
      canvasRef.current.loadFromJSON(history[newIndex], () => {
        canvasRef.current?.renderAll()
      })
    }
  }, [history, historyIndex])

  const redo = useCallback(() => {
    if (historyIndex < history.length - 1 && canvasRef.current) {
      const newIndex = historyIndex + 1
      setHistoryIndex(newIndex)
      canvasRef.current.loadFromJSON(history[newIndex], () => {
        canvasRef.current?.renderAll()
      })
    }
  }, [history, historyIndex])

  return {
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
    canUndo: historyIndex > 0,
    canRedo: historyIndex < history.length - 1
  }
}