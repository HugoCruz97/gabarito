import { Controller } from "@hotwired/stimulus"

// Alterna entre tema claro e escuro e lembra a escolha neste navegador
export default class extends Controller {
  toggle() {
    const root = document.documentElement
    const apply = () => {
      const dark = root.classList.toggle("dark")
      try { localStorage.setItem("theme", dark ? "dark" : "light") } catch (e) {}
    }

    // Transição suave quando o navegador suporta View Transitions
    document.startViewTransition ? document.startViewTransition(apply) : apply()
  }
}
