import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

const SUBJECT_POINTS = 10 // mesmo valor de ExamSubject::POINTS

// Formulário de simulado: adiciona, remove e reordena matérias (arrastando)
// e mostra os totais e a composição da nota ao vivo.
export default class extends Controller {
  static targets = ["rows", "template", "row", "totalQuestions", "totalPoints", "bar", "legend"]
  static values = { colors: Array }

  connect() {
    this.sortable = Sortable.create(this.rowsTarget, {
      handle: "[data-sortable-handle]",
      animation: 180,
      ghostClass: "opacity-30",
      onEnd: () => this.recalculate()
    })
    this.recalculate()
  }

  disconnect() {
    this.sortable?.destroy()
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    const row = this.rowTargets.at(-1)
    row.animate([{ opacity: 0, transform: "translateY(-6px)" }, { opacity: 1, transform: "none" }], { duration: 220, easing: "ease-out" })
    row.querySelector("select")?.focus()
    this.recalculate()
  }

  remove(event) {
    const row = event.target.closest("[data-exam-form-target='row']")
    const finish = () => {
      // Registro já salvo: marca para exclusão. Registro novo: some do DOM.
      if (row.querySelector("input[name$='[id]']")) {
        row.querySelector("[data-exam-form-target='destroy']").value = "1"
        row.hidden = true
      } else {
        row.remove()
      }
      this.recalculate()
    }
    row.animate([{ opacity: 1 }, { opacity: 0, transform: "translateX(12px)" }], { duration: 160, easing: "ease-in" }).onfinish = finish
  }

  recalculate() {
    let totalQuestions = 0
    let totalPoints = 0
    const parts = []

    this.visibleRows.forEach((row, index) => {
      const field = (name) => row.querySelector(`[data-exam-form-target='${name}']`)
      const count = parseInt(field("count").value) || 0
      const select = field("subject")
      // Cada matéria vale SUBJECT_POINTS, divididos igualmente entre as questões
      const subtotal = count > 0 ? SUBJECT_POINTS : 0

      field("perQuestion").textContent = count > 0 ? this.format(SUBJECT_POINTS / count) : "—"
      field("subtotal").textContent = this.format(subtotal)
      field("position").value = index
      totalQuestions += count
      totalPoints += subtotal

      if (select.value && subtotal > 0) {
        parts.push({ name: select.selectedOptions[0].text, value: subtotal, color: this.colorsValue[select.value % this.colorsValue.length] })
      }
    })

    this.totalQuestionsTarget.textContent = totalQuestions
    this.totalPointsTarget.textContent = this.format(totalPoints)
    this.renderComposition(parts, totalPoints)
  }

  renderComposition(parts, total) {
    this.barTarget.innerHTML = parts
      .map((p) => `<span class="transition-all duration-500" style="flex:${p.value};background:${p.color}"></span>`)
      .join("")

    this.legendTarget.innerHTML = parts
      .map((p) => `
        <li class="flex items-center gap-2">
          <span class="size-2 rounded-full" style="background:${p.color}"></span>
          <span class="flex-1 truncate text-cocoa-100">${this.escape(p.name)}</span>
          <span class="font-semibold tabular-nums">${this.format(p.value)}</span>
          <span class="w-10 text-right text-xs text-cocoa-300 tabular-nums">${Math.round((p.value / total) * 100)}%</span>
        </li>`)
      .join("")
  }

  get visibleRows() {
    return this.rowTargets.filter((row) => !row.hidden)
  }

  format(value) {
    return value.toLocaleString("pt-BR", { maximumFractionDigits: 2 })
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
