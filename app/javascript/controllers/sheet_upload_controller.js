import { Controller } from "@hotwired/stimulus"

// Envio de várias fotos de cartão: cada foto vira uma linha com miniatura e
// seletor de aluno. Cada linha tem seu próprio <input type=file> com UM arquivo,
// para o Rails receber sheets[i][image] + sheets[i][student_id] juntos.
export default class extends Controller {
  static targets = ["dropzone", "picker", "list", "template", "row", "count", "missing", "submit"]

  pick() {
    this.add(this.pickerTarget.files)
    this.pickerTarget.value = ""
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.toggleAttribute("data-over", true)
  }

  dragleave() {
    this.dropzoneTarget.toggleAttribute("data-over", false)
  }

  drop(event) {
    event.preventDefault()
    this.dragleave()
    this.add(event.dataTransfer.files)
  }

  add(files) {
    for (const file of files) {
      if (!file.type.startsWith("image/")) continue
      const index = `${Date.now()}${Math.floor(Math.random() * 1000)}`
      const html = this.templateTarget.innerHTML.replaceAll("INDEX", index)
      this.listTarget.insertAdjacentHTML("beforeend", html)
      const row = this.listTarget.lastElementChild

      const transfer = new DataTransfer()
      transfer.items.add(file)
      row.querySelector("[data-role=file]").files = transfer.files
      row.querySelector("[data-role=thumb]").src = URL.createObjectURL(file)
      row.querySelector("[data-role=name]").textContent = file.name
      row.querySelector("[data-role=size]").textContent = `${(file.size / 1024 / 1024).toFixed(1)} MB`
    }
    this.syncStudents()
  }

  remove(event) {
    const row = event.target.closest("[data-sheet-upload-target=row]")
    URL.revokeObjectURL(row.querySelector("[data-role=thumb]").src)
    row.remove()
    this.syncStudents()
  }

  // Um aluno escolhido numa linha fica indisponível nas outras
  syncStudents() {
    const selects = this.rowTargets.map((row) => row.querySelector("[data-role=student]"))
    const chosen = new Set(selects.map((s) => s.value).filter(Boolean))
    selects.forEach((select) => {
      for (const option of select.options) {
        if (!option.value) continue
        option.disabled = option.dataset.taken === "true" || (chosen.has(option.value) && option.value !== select.value)
      }
    })

    const total = this.rowTargets.length
    const missing = selects.filter((s) => !s.value).length
    this.countTarget.textContent = total
    this.submitTarget.disabled = total === 0
    this.missingTarget.hidden = missing === 0
    this.missingTarget.textContent = `${missing} sem aluno escolhido (dá para indicar depois)`
  }

  submit() {
    // o seletor "solto" não deve ir junto (os arquivos já estão nas linhas)
    this.pickerTarget.disabled = true
  }
}
