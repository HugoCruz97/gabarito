import { Controller } from "@hotwired/stimulus"

// Notificação que some sozinha (com barrinha de tempo); pausa ao passar o mouse
export default class extends Controller {
  static targets = ["bar"]
  static values = { duration: { type: Number, default: 4500 } }

  connect() {
    this.animation = this.barTarget.animate(
      [{ transform: "scaleX(1)" }, { transform: "scaleX(0)" }],
      { duration: this.durationValue, easing: "linear", fill: "forwards" }
    )
    this.animation.onfinish = () => this.dismiss()
    this.element.addEventListener("mouseenter", () => this.animation.pause())
    this.element.addEventListener("mouseleave", () => this.animation.play())
  }

  dismiss() {
    this.element.animate(
      [{ opacity: 1, transform: "translateX(0)" }, { opacity: 0, transform: "translateX(24px)" }],
      { duration: 200, easing: "ease-in" }
    ).onfinish = () => this.element.remove()
  }
}
