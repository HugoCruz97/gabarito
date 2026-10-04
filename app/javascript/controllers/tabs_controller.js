import { Controller } from "@hotwired/stimulus"

// Abas simples: botões com data-tabs-key-param mostram o painel de mesmo data-key
export default class extends Controller {
  static targets = ["tab", "panel"]

  select({ params: { key } }) {
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab.dataset.tabsKeyParam === key))
    this.panelTargets.forEach((panel) => (panel.hidden = panel.dataset.key !== key))
  }
}
