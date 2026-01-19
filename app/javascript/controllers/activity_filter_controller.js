import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["callType", "taskType", "status", "search", "results"]

  connect() {
    this.debounceTimer = null
  }

  filter() {
    const params = new URLSearchParams()

    if (this.hasCallTypeTarget && this.callTypeTarget.value) {
      params.set('call_type', this.callTypeTarget.value)
    }
    if (this.hasTaskTypeTarget && this.taskTypeTarget.value) {
      params.set('task_type', this.taskTypeTarget.value)
    }
    if (this.hasStatusTarget && this.statusTarget.value) {
      params.set('status', this.statusTarget.value)
    }
    if (this.hasSearchTarget && this.searchTarget.value) {
      params.set('tool_name', this.searchTarget.value)
    }

    this.loadResults(params)
  }

  debounceFilter() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.filter(), 300)
  }

  async loadResults(params) {
    const url = `/settings/routing/activity?${params.toString()}`

    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = `
        <div class="px-4 py-8 text-center">
          <svg class="animate-spin h-6 w-6 mx-auto text-blue-600" viewBox="0 0 24 24" fill="none">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
      `

      try {
        const response = await fetch(url, {
          headers: {
            'Accept': 'text/html',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
          }
        })

        if (response.ok) {
          const html = await response.text()
          this.resultsTarget.innerHTML = html
        }
      } catch (error) {
        this.resultsTarget.innerHTML = `
          <div class="px-4 py-8 text-center text-red-500">
            <p class="text-sm">Failed to load results</p>
          </div>
        `
      }
    }
  }
}
