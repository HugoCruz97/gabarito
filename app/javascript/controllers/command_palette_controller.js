import { Controller } from "@hotwired/stimulus"

// Paleta de comandos (Ctrl+K): filtra ações rápidas e busca no servidor
export default class extends Controller {
  static targets = ["dialog", "input", "actions", "results", "item"]

  open() {
    if (this.dialogTarget.open) return
    this.dialogTarget.showModal()
    this.inputTarget.focus()
    this.select(0)
  }

  reset() {
    this.inputTarget.value = ""
    this.resultsTarget.removeAttribute("src")
    this.resultsTarget.innerHTML = ""
    this.filterActions("")
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  search() {
    const query = this.inputTarget.value.trim()
    this.filterActions(query.toLowerCase())

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      if (query.length < 2) {
        this.resultsTarget.removeAttribute("src")
        this.resultsTarget.innerHTML = ""
      } else {
        this.resultsTarget.src = `/search?q=${encodeURIComponent(query)}`
      }
    }, 150)
    this.select(0)
  }

  // Quando os resultados do servidor chegam, seleciona o primeiro item visível
  itemTargetConnected() {
    if (this.selectedIndex === undefined || !this.visibleItems[this.selectedIndex]) this.select(0)
    else this.select(this.selectedIndex)
  }

  navigate(event) {
    const items = this.visibleItems
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.select(Math.min(this.selectedIndex + 1, items.length - 1))
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.select(Math.max(this.selectedIndex - 1, 0))
    } else if (event.key === "Enter") {
      event.preventDefault()
      const item = items[this.selectedIndex]
      if (item) {
        this.dialogTarget.close()
        Turbo.visit(item.href)
      }
    }
  }

  filterActions(query) {
    let visible = 0
    this.actionsTarget.querySelectorAll("[data-command-palette-target='item']").forEach((item) => {
      const match = !query || item.dataset.label.includes(query)
      item.hidden = !match
      if (match) visible++
    })
    this.actionsTarget.hidden = visible === 0
  }

  select(index) {
    this.selectedIndex = index
    this.visibleItems.forEach((item, i) => {
      item.setAttribute("aria-selected", i === index)
      if (i === index) item.scrollIntoView({ block: "nearest" })
    })
  }

  get visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden && !item.closest("[hidden]"))
  }
}
