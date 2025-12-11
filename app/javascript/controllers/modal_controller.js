import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    newUrl: String,
    editUrl: String
  }

  connect() {
    document.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  handleSubmitEnd = (event) => {
    if (event.detail.success) {
      const modal = bootstrap.Modal.getInstance(document.getElementById("RconModal"))
      modal?.hide()
    }
  }

  loadNew() {
    const frame = document.getElementById("rcon_modal_content")
    if (frame) {
      frame.src = this.newUrlValue
    }
  }

  loadEdit(event) {
    const templateId = event.currentTarget.dataset.templateId
    const frame = document.getElementById("rcon_modal_content")
    if (frame && templateId) {
      frame.src = this.editUrlValue.replace(":id", templateId)
    }
  }
}
