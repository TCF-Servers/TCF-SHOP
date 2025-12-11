import { Controller } from "@hotwired/stimulus"
import Swal from "sweetalert2"

export default class extends Controller {
  static values = {
    title: { type: String, default: "Confirmer" },
    text: { type: String, default: "Cette action est irréversible." },
    confirmText: { type: String, default: "Supprimer" },
    cancelText: { type: String, default: "Annuler" },
    url: String,
    method: { type: String, default: "delete" }
  }

  async confirm(event) {
    event.preventDefault()

    const result = await Swal.fire({
      title: this.titleValue,
      text: this.textValue,
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: this.confirmTextValue,
      cancelButtonText: this.cancelTextValue,
      background: "#1f1f1f",
      color: "#f5f5f5",
      iconColor: "#f97316",
      customClass: {
        popup: "swal-admin-popup",
        title: "swal-admin-title",
        htmlContainer: "swal-admin-text",
        confirmButton: "swal-admin-confirm",
        cancelButton: "swal-admin-cancel",
        actions: "swal-admin-actions"
      },
      buttonsStyling: false
    })

    if (result.isConfirmed) {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(this.urlValue, {
        method: this.methodValue.toUpperCase(),
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    }
  }
}
