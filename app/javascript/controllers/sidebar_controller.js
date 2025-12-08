import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
  }

  toggle() {
    document.body.classList.toggle("admin-sidebar-open")
  }

  close() {
    document.body.classList.remove("admin-sidebar-open")
  }

  handleResize() {
    if (window.innerWidth > 1024) {
      this.close()
    }
  }
}
