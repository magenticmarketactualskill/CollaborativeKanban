import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "modal", "form"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('keydown', this.boundHandleKeydown)
    document.addEventListener('click', this.boundHandleClickOutside)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleKeydown)
    document.removeEventListener('click', this.boundHandleClickOutside)
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closeMenu()
      this.closeModal()
    }
  }

  handleClickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  toggleMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle('hidden')
    }
  }

  closeMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add('hidden')
    }
  }

  openModal() {
    this.closeMenu()
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
    }
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
    }
  }

  selectProvider(event) {
    const provider = event.currentTarget.dataset.provider
    const localSection = document.getElementById('local-llm-settings')
    const remoteSection = document.getElementById('remote-api-settings')
    const localTab = document.getElementById('local-tab')
    const remoteTab = document.getElementById('remote-tab')

    if (provider === 'local') {
      localSection.classList.remove('hidden')
      remoteSection.classList.add('hidden')
      localTab.classList.add('bg-blue-600', 'text-white')
      localTab.classList.remove('bg-gray-200', 'text-gray-700')
      remoteTab.classList.remove('bg-blue-600', 'text-white')
      remoteTab.classList.add('bg-gray-200', 'text-gray-700')
    } else {
      remoteSection.classList.remove('hidden')
      localSection.classList.add('hidden')
      remoteTab.classList.add('bg-blue-600', 'text-white')
      remoteTab.classList.remove('bg-gray-200', 'text-gray-700')
      localTab.classList.remove('bg-blue-600', 'text-white')
      localTab.classList.add('bg-gray-200', 'text-gray-700')
    }
  }

  async testConnection(event) {
    const button = event.currentTarget
    const originalText = button.textContent
    button.textContent = 'Testing...'
    button.disabled = true

    const formData = new FormData(this.formTarget)

    try {
      const response = await fetch('/settings/test_connection', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: formData
      })

      const result = await response.json()

      if (result.success) {
        button.textContent = 'Connected!'
        button.classList.remove('bg-gray-600')
        button.classList.add('bg-green-600')
        setTimeout(() => {
          button.textContent = originalText
          button.classList.remove('bg-green-600')
          button.classList.add('bg-gray-600')
          button.disabled = false
        }, 2000)
      } else {
        button.textContent = 'Failed'
        button.classList.remove('bg-gray-600')
        button.classList.add('bg-red-600')
        setTimeout(() => {
          button.textContent = originalText
          button.classList.remove('bg-red-600')
          button.classList.add('bg-gray-600')
          button.disabled = false
        }, 2000)
      }
    } catch (error) {
      button.textContent = 'Error'
      button.classList.remove('bg-gray-600')
      button.classList.add('bg-red-600')
      setTimeout(() => {
        button.textContent = originalText
        button.classList.remove('bg-red-600')
        button.classList.add('bg-gray-600')
        button.disabled = false
      }, 2000)
    }
  }
}
