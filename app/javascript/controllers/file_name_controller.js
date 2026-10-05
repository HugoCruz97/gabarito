import { Controller } from "@hotwired/stimulus"

// Mostra o nome do arquivo escolhido no lugar do texto do campo de envio
export default class extends Controller {
  static targets = ["input", "label"]

  update() {
    const file = this.inputTarget.files[0]
    if (file) this.labelTarget.textContent = file.name
  }
}
