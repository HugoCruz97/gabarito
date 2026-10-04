import { Controller } from "@hotwired/stimulus"

// Menu lateral deslizante no celular
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.close = this.close.bind(this)
    document.addEventListener("turbo:visit", this.close)
  }

  disconnect() {
    document.removeEventListener("turbo:visit", this.close)
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }
}
