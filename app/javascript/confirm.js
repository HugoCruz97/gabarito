import { Turbo } from "@hotwired/turbo-rails"

// Usa um <dialog> bonito no lugar do confirm() nativo para data-turbo-confirm
Turbo.config.forms.confirm = (message) => {
  const dialog = document.getElementById("confirm-dialog")
  dialog.querySelector("[data-confirm-message]").textContent = message
  dialog.showModal()

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  })
}
