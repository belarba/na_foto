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

// Compress image to max 800px, JPEG 60% quality
function compressImage(file) {
  return new Promise((resolve) => {
    if (!file.type.startsWith("image/")) return resolve(file)

    const img = new Image()
    const url = URL.createObjectURL(file)

    img.onload = () => {
      URL.revokeObjectURL(url)
      const MAX = 800
      const { width, height } = img
      const ratio = Math.min(MAX / width, MAX / height, 1)
      const newW = Math.round(width * ratio)
      const newH = Math.round(height * ratio)

      const canvas = document.createElement("canvas")
      canvas.width = newW
      canvas.height = newH
      canvas.getContext("2d").drawImage(img, 0, 0, newW, newH)

      canvas.toBlob((blob) => {
        if (blob) {
          console.log(`[NA_FOTO] ${(file.size/1024).toFixed(0)}KB → ${(blob.size/1024).toFixed(0)}KB (${newW}x${newH})`)
          resolve(new File([blob], file.name.replace(/\.\w+$/, ".jpg"), { type: "image/jpeg", lastModified: Date.now() }))
        } else {
          resolve(file)
        }
      }, "image/jpeg", 0.6)
    }
    img.onerror = () => { URL.revokeObjectURL(url); resolve(file) }
    img.src = url
  })
}

// Inject a compressed file into a LiveView live_file_input
function injectFileIntoLiveInput(file) {
  const liveInput = document.querySelector("input[data-phx-upload-ref]")
  if (!liveInput) return
  const dt = new DataTransfer()
  dt.items.add(file)
  liveInput.files = dt.files
  liveInput.dispatchEvent(new Event("input", { bubbles: true }))
}

// Custom hooks
const Hooks = {
  StoryGenerator,

  // Main hook: detects mobile + creates proxy input for compressed uploads
  ImageProxy: {
    mounted() {
      this.pushEvent("mobile_detected", { is_mobile: isMobile })

      // Create a hidden proxy input (not managed by LiveView)
      const proxy = document.createElement("input")
      proxy.type = "file"
      proxy.accept = "image/*"
      proxy.style.display = "none"
      proxy.id = "image-proxy-input"
      document.body.appendChild(proxy)

      // When proxy gets a file, compress and inject into LiveView input
      proxy.addEventListener("change", async () => {
        if (!proxy.files || proxy.files.length === 0) return
        const file = proxy.files[0]
        console.log(`[NA_FOTO] selected: ${file.name} (${(file.size/1024).toFixed(0)}KB)`)

        let toUpload = file
        if (file.size > 100000) {
          toUpload = await compressImage(file)
        }

        injectFileIntoLiveInput(toUpload)
        proxy.value = "" // reset for next selection
      })

      // Also handle drag & drop: intercept drop, compress, inject
      this.el.addEventListener("drop", async (e) => {
        const files = e.dataTransfer?.files
        if (!files || files.length === 0) return
        const file = files[0]
        if (!file.type.startsWith("image/")) return

        e.preventDefault()
        e.stopPropagation()

        let toUpload = file
        if (file.size > 100000) {
          toUpload = await compressImage(file)
        }
        injectFileIntoLiveInput(toUpload)
      }, true)

      this.el.addEventListener("dragover", (e) => {
        e.preventDefault()
      })

      this._proxy = proxy
    },
    destroyed() {
      if (this._proxy) this._proxy.remove()
    }
  },

  // Gallery button: opens proxy input without capture
  GalleryPick: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        e.preventDefault()
        const proxy = document.getElementById("image-proxy-input")
        if (proxy) {
          proxy.removeAttribute("capture")
          proxy.click()
        }
      })
    }
  },

  // Camera button: opens proxy input with capture
  CameraCapture: {
    mounted() {
      this.el.addEventListener("click", (e) => {
        e.preventDefault()
        const proxy = document.getElementById("image-proxy-input")
        if (proxy) {
          proxy.setAttribute("capture", "environment")
          proxy.click()
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

