// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/na_foto"
import topbar from "../vendor/topbar"
import StoryGenerator from "./story_generator"

// Detect mobile device
const isMobile = /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

// Aggressively resize image before upload: max 800px, JPEG 60% quality
// The AI model only needs 512x512, so 800px is more than enough
const MAX_DIMENSION = 800
const JPEG_QUALITY = 0.6

function compressImage(file) {
  return new Promise((resolve) => {
    if (!file.type.startsWith("image/")) return resolve(file)

    const img = new Image()
    const url = URL.createObjectURL(file)

    img.onload = () => {
      URL.revokeObjectURL(url)

      const { width, height } = img
      const ratio = Math.min(MAX_DIMENSION / width, MAX_DIMENSION / height, 1)
      const newW = Math.round(width * ratio)
      const newH = Math.round(height * ratio)

      const canvas = document.createElement("canvas")
      canvas.width = newW
      canvas.height = newH
      const ctx = canvas.getContext("2d")
      ctx.drawImage(img, 0, 0, newW, newH)

      canvas.toBlob((blob) => {
        if (blob) {
          console.log(`[NA_FOTO] compressed: ${(file.size/1024).toFixed(0)}KB → ${(blob.size/1024).toFixed(0)}KB (${newW}x${newH})`)
          resolve(new File([blob], file.name, { type: "image/jpeg", lastModified: Date.now() }))
        } else {
          resolve(file)
        }
      }, "image/jpeg", JPEG_QUALITY)
    }

    img.onerror = () => {
      URL.revokeObjectURL(url)
      resolve(file)
    }

    img.src = url
  })
}

// Custom hooks
const Hooks = {
  // Detects mobile and sets up image compression
  MobileDetect: {
    mounted() {
      this.pushEvent("mobile_detected", { is_mobile: isMobile })
      this._compressing = false

      // Intercept file selection to compress before upload
      this.el.addEventListener("change", async (e) => {
        const input = e.target
        if (!input.matches("input[type=file]")) return
        if (!input.files || input.files.length === 0) return
        if (this._compressing) return // avoid re-entry

        const file = input.files[0]
        if (!file.type.startsWith("image/")) return

        // Stop LiveView from processing original
        e.stopImmediatePropagation()

        this._compressing = true

        try {
          const compressed = await compressImage(file)
          console.log(`[NA_FOTO] upload ready: ${(compressed.size/1024).toFixed(0)}KB`)

          // Replace file in input
          const dt = new DataTransfer()
          dt.items.add(compressed)
          input.files = dt.files
        } catch(err) {
          console.error("[NA_FOTO] compression failed:", err)
        }

        this._compressing = false

        // Let LiveView process the compressed file
        input.dispatchEvent(new Event("input", { bubbles: true }))
      }, { capture: true })
    }
  },
  // Camera capture: temporarily add capture attribute to the LiveView file input
  StoryGenerator,
  CameraCapture: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        e.preventDefault()
        const liveInput = document.querySelector("input[data-phx-upload-ref]")
        if (liveInput) {
          // Remove capture on change (after photo taken) or after 60s timeout
          const cleanup = () => {
            liveInput.removeAttribute("capture")
            liveInput.removeEventListener("change", cleanup)
          }
          liveInput.addEventListener("change", cleanup, { once: true })
          setTimeout(cleanup, 60000)

          liveInput.setAttribute("capture", "environment")
          liveInput.click()
        }
      })
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})


// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

