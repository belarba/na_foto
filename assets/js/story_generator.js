// Story Generator - Creates Instagram Stories (1080x1920) from analysis results
// Uses Canvas API to render 2 slides client-side

const STORY_W = 1080
const STORY_H = 1920
const BG_COLOR = "#111827"
const ACCENT = "#34D399"
const PADDING = 60

// Load Press Start 2P font for canvas
function ensureFont() {
  return document.fonts.ready
}

function drawPixelBorder(ctx, x, y, w, h, color = "#34D399", thickness = 4) {
  ctx.strokeStyle = color
  ctx.lineWidth = thickness
  ctx.strokeRect(x, y, w, h)
  // Shadow
  ctx.fillStyle = "rgba(0,0,0,0.3)"
  ctx.fillRect(x + thickness, y + h, w, thickness)
  ctx.fillRect(x + w, y + thickness, thickness, h)
}

function drawText(ctx, text, x, y, { font = "16px 'Press Start 2P'", color = "#fff", align = "left", maxWidth = null } = {}) {
  ctx.font = font
  ctx.fillStyle = color
  ctx.textAlign = align
  ctx.textBaseline = "top"
  if (maxWidth) {
    ctx.fillText(text, x, y, maxWidth)
  } else {
    ctx.fillText(text, x, y)
  }
}

function drawBar(ctx, x, y, w, h, percentage, color) {
  // Background
  ctx.fillStyle = "#1F2937"
  ctx.fillRect(x, y, w, h)
  // Fill
  ctx.fillStyle = color
  ctx.fillRect(x, y, w * (percentage / 100), h)
  // Border
  ctx.strokeStyle = "#374151"
  ctx.lineWidth = 2
  ctx.strokeRect(x, y, w, h)
}

async function generateSlide1(data) {
  await ensureFont()

  const canvas = document.createElement("canvas")
  canvas.width = STORY_W
  canvas.height = STORY_H
  const ctx = canvas.getContext("2d")

  // Background
  ctx.fillStyle = BG_COLOR
  ctx.fillRect(0, 0, STORY_W, STORY_H)

  // Scanlines effect
  ctx.fillStyle = "rgba(255,255,255,0.02)"
  for (let i = 0; i < STORY_H; i += 4) {
    ctx.fillRect(0, i, STORY_W, 1)
  }

  // Header
  drawText(ctx, "NA FOTO", STORY_W / 2, 80, {
    font: "48px 'Press Start 2P'",
    color: ACCENT,
    align: "center"
  })

  // Subtitle
  drawText(ctx, "ANALISE DE IMAGEM", STORY_W / 2, 150, {
    font: "14px 'Silkscreen'",
    color: "#6B7280",
    align: "center"
  })

  // Load and draw image
  const img = await loadImage(data.image)
  const imgArea = { x: PADDING, y: 220, w: STORY_W - PADDING * 2, h: STORY_H * 0.5 }

  // Fit image maintaining aspect ratio
  const imgRatio = img.width / img.height
  const areaRatio = imgArea.w / imgArea.h
  let drawW, drawH, drawX, drawY

  if (imgRatio > areaRatio) {
    drawW = imgArea.w
    drawH = imgArea.w / imgRatio
    drawX = imgArea.x
    drawY = imgArea.y + (imgArea.h - drawH) / 2
  } else {
    drawH = imgArea.h
    drawW = imgArea.h * imgRatio
    drawX = imgArea.x + (imgArea.w - drawW) / 2
    drawY = imgArea.y
  }

  // Pixel border around image
  drawPixelBorder(ctx, drawX - 6, drawY - 6, drawW + 12, drawH + 12, ACCENT)
  ctx.drawImage(img, drawX, drawY, drawW, drawH)

  // Draw annotation labels on image
  const annotations = data.annotations || []
  annotations.forEach((ann) => {
    const px = drawX + (ann.cx / 100) * drawW
    const py = drawY + (ann.cy / 100) * drawH

    // Dot
    ctx.beginPath()
    ctx.arc(px, py, 8, 0, Math.PI * 2)
    ctx.fillStyle = ann.color
    ctx.fill()
    ctx.strokeStyle = "#000"
    ctx.lineWidth = 2
    ctx.stroke()

    // Label background
    const label = `${ann.category.toUpperCase()} ${ann.percentage}%`
    ctx.font = "10px 'Press Start 2P'"
    const metrics = ctx.measureText(label)
    const labelW = metrics.width + 16
    const labelH = 24
    const labelX = Math.min(Math.max(px - labelW / 2, drawX + 4), drawX + drawW - labelW - 4)
    const labelY = py - labelH - 14

    ctx.fillStyle = ann.color
    ctx.fillRect(labelX, labelY, labelW, labelH)
    ctx.strokeStyle = "#000"
    ctx.lineWidth = 1
    ctx.strokeRect(labelX, labelY, labelW, labelH)

    drawText(ctx, label, labelX + 8, labelY + 7, {
      font: "10px 'Press Start 2P'",
      color: "#fff"
    })
  })

  // Segmentation summary below image
  const summaryY = drawY + drawH + 50
  annotations.forEach((ann, i) => {
    const barY = summaryY + i * 55
    if (barY + 50 > STORY_H - 120) return

    const labelText = ann.category.toUpperCase()
    drawText(ctx, labelText, PADDING, barY, {
      font: "12px 'Press Start 2P'",
      color: "#9CA3AF"
    })

    const barX = PADDING
    const barW = STORY_W - PADDING * 2 - 120
    drawBar(ctx, barX, barY + 22, barW, 20, ann.percentage, ann.color)

    drawText(ctx, `${ann.percentage}%`, barX + barW + 10, barY + 22, {
      font: "12px 'Press Start 2P'",
      color: "#E5E7EB"
    })
  })

  // Footer
  drawText(ctx, "nafoto.app", STORY_W / 2, STORY_H - 80, {
    font: "12px 'Press Start 2P'",
    color: "#374151",
    align: "center"
  })

  return canvas
}

async function generateSlide2(data) {
  await ensureFont()

  const canvas = document.createElement("canvas")
  canvas.width = STORY_W
  canvas.height = STORY_H
  const ctx = canvas.getContext("2d")

  // Background
  ctx.fillStyle = BG_COLOR
  ctx.fillRect(0, 0, STORY_W, STORY_H)

  // Scanlines
  ctx.fillStyle = "rgba(255,255,255,0.02)"
  for (let i = 0; i < STORY_H; i += 4) {
    ctx.fillRect(0, i, STORY_W, 1)
  }

  // Header
  drawText(ctx, "ANALISE", STORY_W / 2, 80, {
    font: "48px 'Press Start 2P'",
    color: "#FBBF24",
    align: "center"
  })

  let curY = 180

  // Color distribution section
  const colors = data.colors || {}
  const colorEntries = Object.entries(colors).sort((a, b) => b[1] - a[1])

  if (colorEntries.length > 0) {
    drawText(ctx, "> CORES", PADDING, curY, {
      font: "20px 'Press Start 2P'",
      color: "#FBBF24"
    })
    curY += 50

    colorEntries.forEach(([name, pct]) => {
      if (curY > 900) return
      const cssColor = data.colorMap[name] || "#6B7280"

      drawText(ctx, name.toUpperCase(), PADDING, curY, {
        font: "12px 'Press Start 2P'",
        color: "#9CA3AF"
      })

      const barX = PADDING
      const barW = STORY_W - PADDING * 2 - 120
      drawBar(ctx, barX, curY + 22, barW, 20, pct, cssColor)

      drawText(ctx, `${pct}%`, barX + barW + 10, curY + 22, {
        font: "12px 'Press Start 2P'",
        color: "#E5E7EB"
      })

      curY += 55
    })
  }

  // Dominant colors palette
  const dominantColors = data.dominantColors || []
  if (dominantColors.length > 0) {
    curY = Math.max(curY + 30, 950)

    drawText(ctx, "> PALETA", PADDING, curY, {
      font: "20px 'Press Start 2P'",
      color: "#D946EF"
    })
    curY += 60

    const swatchSize = 120
    const gap = 30
    const totalW = dominantColors.length * swatchSize + (dominantColors.length - 1) * gap
    const startX = (STORY_W - totalW) / 2

    dominantColors.forEach((color, i) => {
      const sx = startX + i * (swatchSize + gap)

      // Swatch
      ctx.fillStyle = color.hex
      ctx.fillRect(sx, curY, swatchSize, swatchSize)
      drawPixelBorder(ctx, sx, curY, swatchSize, swatchSize, "#000", 3)

      // Hex label
      drawText(ctx, color.hex, sx + swatchSize / 2, curY + swatchSize + 12, {
        font: "10px 'Press Start 2P'",
        color: "#9CA3AF",
        align: "center"
      })

      // Percentage
      drawText(ctx, `${color.percentage}%`, sx + swatchSize / 2, curY + swatchSize + 32, {
        font: "10px 'Silkscreen'",
        color: "#6B7280",
        align: "center"
      })
    })

    curY += swatchSize + 70
  }

  // Segmentation summary
  const annotations = data.annotations || []
  if (annotations.length > 0) {
    curY = Math.max(curY + 20, 1350)

    drawText(ctx, "> SEGMENTACAO", PADDING, curY, {
      font: "20px 'Press Start 2P'",
      color: ACCENT
    })
    curY += 50

    annotations.forEach((ann) => {
      if (curY > STORY_H - 150) return

      drawText(ctx, ann.category.toUpperCase(), PADDING, curY, {
        font: "12px 'Press Start 2P'",
        color: "#9CA3AF"
      })

      const barX = PADDING
      const barW = STORY_W - PADDING * 2 - 120
      drawBar(ctx, barX, curY + 22, barW, 20, ann.percentage, ann.color)

      drawText(ctx, `${ann.percentage}%`, barX + barW + 10, curY + 22, {
        font: "12px 'Press Start 2P'",
        color: "#E5E7EB"
      })

      curY += 55
    })
  }

  // Footer
  drawText(ctx, "NA FOTO", STORY_W / 2, STORY_H - 100, {
    font: "16px 'Press Start 2P'",
    color: ACCENT,
    align: "center"
  })
  drawText(ctx, "AI IMAGE ANALYSIS", STORY_W / 2, STORY_H - 65, {
    font: "10px 'Silkscreen'",
    color: "#374151",
    align: "center"
  })

  return canvas
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.onload = () => resolve(img)
    img.onerror = reject
    img.src = src
  })
}

function canvasToBlob(canvas) {
  return new Promise((resolve) => {
    canvas.toBlob(resolve, "image/png")
  })
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

// Main hook
const StoryGenerator = {
  mounted() {
    this.el.addEventListener("click", () => this.generate())
  },

  updated() {
    // Re-bind if element updates
  },

  async generate() {
    const btn = this.el
    const originalText = btn.textContent
    btn.textContent = "A GERAR..."
    btn.disabled = true

    try {
      // Get image from DOM, other data from data attributes
      const imgEl = document.getElementById("analyzed-image")
      const data = {
        image: imgEl ? imgEl.src : "",
        annotations: JSON.parse(btn.dataset.annotations || "[]"),
        colors: JSON.parse(btn.dataset.colors || "{}"),
        colorMap: {
          "vermelho": "#EF4444", "laranja": "#F97316", "amarelo": "#EAB308",
          "verde": "#22C55E", "azul": "#3B82F6", "roxo": "#A855F7",
          "castanho": "#92400E", "cinzento": "#9CA3AF", "branco": "#E5E7EB", "preto": "#1F2937"
        },
        dominantColors: JSON.parse(btn.dataset.dominantColors || "[]")
      }

      const [canvas1, canvas2] = await Promise.all([
        generateSlide1(data),
        generateSlide2(data)
      ])

      const [blob1, blob2] = await Promise.all([
        canvasToBlob(canvas1),
        canvasToBlob(canvas2)
      ])

      // Try Web Share API (mobile)
      if (navigator.canShare) {
        const files = [
          new File([blob1], "na-foto-slide1.png", { type: "image/png" }),
          new File([blob2], "na-foto-slide2.png", { type: "image/png" })
        ]

        if (navigator.canShare({ files })) {
          try {
            await navigator.share({
              files,
              title: "Na Foto",
              text: "O que tem Na Foto..."
            })
            btn.textContent = originalText
            btn.disabled = false
            return
          } catch (e) {
            // User cancelled or share failed, fallback to modal
            if (e.name === "AbortError") {
              btn.textContent = originalText
              btn.disabled = false
              return
            }
          }
        }
      }

      // Fallback: show modal with previews + download buttons
      this.showModal(canvas1, canvas2, blob1, blob2)
    } catch (e) {
      console.error("Story generation error:", e)
      btn.textContent = "ERRO!"
      setTimeout(() => {
        btn.textContent = originalText
        btn.disabled = false
      }, 2000)
      return
    }

    btn.textContent = originalText
    btn.disabled = false
  },

  showModal(canvas1, canvas2, blob1, blob2) {
    // Remove existing modal
    const existing = document.getElementById("story-modal")
    if (existing) existing.remove()

    const modal = document.createElement("div")
    modal.id = "story-modal"
    modal.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
    modal.style.backdropFilter = "blur(4px)"

    modal.innerHTML = `
      <div class="bg-zinc-900 pixel-border border-emerald-500 p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-4">
          <h3 class="font-pixel text-sm text-emerald-400">> STORIES</h3>
          <button id="story-close" class="font-pixel text-xs text-zinc-500 hover:text-red-400">X</button>
        </div>
        <div class="grid grid-cols-2 gap-4 mb-6">
          <div class="text-center">
            <p class="font-silk text-xs text-zinc-500 mb-2">SLIDE 1</p>
            <img id="story-preview-1" class="w-full border border-zinc-700" />
          </div>
          <div class="text-center">
            <p class="font-silk text-xs text-zinc-500 mb-2">SLIDE 2</p>
            <img id="story-preview-2" class="w-full border border-zinc-700" />
          </div>
        </div>
        <div class="flex gap-3 justify-center flex-wrap">
          <button id="story-dl-1" class="font-pixel text-[10px] px-4 py-2 bg-emerald-600 text-white pixel-border-sm border-emerald-400 hover:bg-emerald-500">
            DOWNLOAD SLIDE 1
          </button>
          <button id="story-dl-2" class="font-pixel text-[10px] px-4 py-2 bg-amber-600 text-white pixel-border-sm border-amber-400 hover:bg-amber-500">
            DOWNLOAD SLIDE 2
          </button>
          <button id="story-dl-all" class="font-pixel text-[10px] px-4 py-2 bg-fuchsia-600 text-white pixel-border-sm border-fuchsia-400 hover:bg-fuchsia-500">
            DOWNLOAD AMBOS
          </button>
        </div>
      </div>
    `

    document.body.appendChild(modal)

    // Set preview images
    document.getElementById("story-preview-1").src = canvas1.toDataURL("image/png")
    document.getElementById("story-preview-2").src = canvas2.toDataURL("image/png")

    // Event listeners
    document.getElementById("story-close").addEventListener("click", () => modal.remove())
    modal.addEventListener("click", (e) => { if (e.target === modal) modal.remove() })

    document.getElementById("story-dl-1").addEventListener("click", () => downloadBlob(blob1, "na-foto-slide1.png"))
    document.getElementById("story-dl-2").addEventListener("click", () => downloadBlob(blob2, "na-foto-slide2.png"))
    document.getElementById("story-dl-all").addEventListener("click", () => {
      downloadBlob(blob1, "na-foto-slide1.png")
      setTimeout(() => downloadBlob(blob2, "na-foto-slide2.png"), 500)
    })
  }
}

export default StoryGenerator
