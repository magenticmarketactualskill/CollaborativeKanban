import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.element.setAttribute('draggable', 'true')
  }
}
