import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    // Close on escape key
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  close() {
    const drawer = this.element.closest('#card-drawer')
    if (drawer) {
      drawer.classList.add('hidden')
    }
  }
}
