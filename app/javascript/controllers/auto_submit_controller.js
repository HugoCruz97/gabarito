import { Controller } from "@hotwired/stimulus"

// Envia o formulário automaticamente enquanto o usuário digita (com uma pequena espera).
export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 250)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
