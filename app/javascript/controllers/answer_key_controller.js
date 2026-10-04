import { Controller } from "@hotwired/stimulus"

// Gabarito pelo teclado: digite a letra e o cursor pula para a próxima questão.
export default class extends Controller {
  static targets = ["question", "annul", "progressBar", "progressCount", "progressTotal"]
  static values = { options: String }

  connect() {
    const firstEmpty = this.questionTargets.findIndex((q) => !this.isFilled(q))
    this.current = firstEmpty === -1 ? 0 : firstEmpty
    this.highlight(false)
    this.refresh()
  }

  keydown(event) {
    // Deixa o Ctrl+K da busca e campos de texto em paz
    if (event.target.matches?.("input[type=text], input[type=search], input[type=number], textarea, select") || document.querySelector("dialog[open]")) return

    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
      event.preventDefault()
      this.element.requestSubmit()
      return
    }
    if (event.ctrlKey || event.metaKey || event.altKey) return

    const key = event.key.toUpperCase()
    const question = this.questionTargets[this.current]

    if (this.optionsValue.includes(key) && key.length === 1) {
      event.preventDefault()
      if (this.annulCheckbox(question).checked) return this.shake(question) // anulada não tem alternativa
      this.radio(question, key).checked = true
      this.pulse(question)
      this.refresh()
      this.move(1)
    } else if (key === "X") {
      event.preventDefault()
      const annul = this.annulCheckbox(question)
      annul.checked = !annul.checked
      this.refresh()
    } else if (event.key === "Backspace" || event.key === "Delete") {
      event.preventDefault()
      question.querySelectorAll("input[type=radio]").forEach((r) => (r.checked = false))
      this.refresh()
      if (event.key === "Backspace") this.move(-1)
    } else if (event.key === "ArrowRight" || event.key === "ArrowDown" || event.key === "Enter") {
      event.preventDefault()
      this.move(1)
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault()
      this.move(-1)
    }
  }

  focusQuestion(event) {
    this.current = this.questionTargets.indexOf(event.currentTarget)
    this.highlight(false)
  }

  answered(event) {
    // Clique com o mouse numa bolinha também avança
    this.current = this.questionTargets.indexOf(event.target.closest("[data-answer-key-target='question']"))
    this.refresh()
    this.move(1)
  }

  move(step) {
    this.current = Math.max(0, Math.min(this.questionTargets.length - 1, this.current + step))
    this.highlight()
  }

  highlight(scroll = true) {
    this.questionTargets.forEach((q, i) => q.toggleAttribute("data-current", i === this.current))
    if (scroll) this.questionTargets[this.current]?.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  refresh() {
    let filled = 0
    this.questionTargets.forEach((q) => {
      const annulled = this.annulCheckbox(q).checked
      q.toggleAttribute("data-annulled", annulled)
      // Anulada não tem alternativa correta: limpa e trava as bolinhas
      q.querySelectorAll("input[type=radio]").forEach((radio) => {
        if (annulled) radio.checked = false
        radio.disabled = annulled
      })
      if (this.isFilled(q)) filled++
    })
    const total = this.questionTargets.length
    this.progressCountTarget.textContent = filled
    this.progressTotalTarget.textContent = total
    this.progressBarTarget.style.width = `${total ? (filled / total) * 100 : 0}%`
  }

  isFilled(question) {
    return !!question.querySelector("input[type=radio]:checked") || this.annulCheckbox(question).checked
  }

  annulCheckbox(question) {
    return question.querySelector("[data-answer-key-target='annul']")
  }

  shake(question) {
    question.animate(
      [{ transform: "translateX(0)" }, { transform: "translateX(-5px)" }, { transform: "translateX(5px)" }, { transform: "translateX(0)" }],
      { duration: 220 }
    )
  }

  radio(question, option) {
    return question.querySelector(`input[type=radio][value='${option}']`)
  }

  pulse(question) {
    question.animate([{ transform: "scale(1)" }, { transform: "scale(1.02)" }, { transform: "scale(1)" }], { duration: 180 })
  }
}
