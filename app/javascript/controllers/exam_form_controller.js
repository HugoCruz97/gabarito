import { Controller } from "@hotwired/stimulus"

// Formulário de simulado: adiciona/remove matérias e mostra os totais ao vivo.
export default class extends Controller {
  static targets = ["rows", "template", "row", "count", "points", "subtotal", "destroy", "position", "totalQuestions", "totalPoints"]

  connect() {
    this.recalculate()
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.rowTargets.at(-1).querySelector("select")?.focus()
    this.recalculate()
  }

  remove(event) {
    const row = event.target.closest("[data-exam-form-target='row']")
    const destroy = row.querySelector("[data-exam-form-target='destroy']")
    // Registro já salvo: marca para exclusão. Registro novo: some do DOM.
    if (row.querySelector("input[name$='[id]']")) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
    this.recalculate()
  }

  recalculate() {
    let totalQuestions = 0
    let totalPoints = 0

    this.visibleRows.forEach((row, index) => {
      const count = parseInt(row.querySelector("[data-exam-form-target='count']").value) || 0
      const points = parseFloat(row.querySelector("[data-exam-form-target='points']").value) || 0
      row.querySelector("[data-exam-form-target='subtotal']").textContent = this.format(count * points)
      row.querySelector("[data-exam-form-target='position']").value = index
      totalQuestions += count
      totalPoints += count * points
    })

    this.totalQuestionsTarget.textContent = totalQuestions
    this.totalPointsTarget.textContent = this.format(totalPoints)
  }

  get visibleRows() {
    return this.rowTargets.filter((row) => !row.hidden)
  }

  format(value) {
    return value.toLocaleString("pt-BR", { maximumFractionDigits: 2 })
  }
}
