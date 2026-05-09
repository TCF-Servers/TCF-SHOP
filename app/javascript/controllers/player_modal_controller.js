import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
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
      const modal = bootstrap.Modal.getInstance(document.getElementById("PlayerModal"))
      modal?.hide()
    }
  }

  loadEdit(event) {
    const playerId = event.currentTarget.dataset.playerId
    const frame = document.getElementById("player_modal_content")
    if (frame && playerId) {
      frame.src = this.editUrlValue.replace(":id", playerId)
    }
  }
}
