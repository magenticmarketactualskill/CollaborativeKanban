import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["activityFeed", "statisticsCards", "refreshIcon"]
  static values = {
    refreshInterval: { type: Number, default: 30000 }
  }

  connect() {
    this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.refreshStatistics()
    }, this.refreshIntervalValue)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  async refresh() {
    if (this.hasRefreshIconTarget) {
      this.refreshIconTarget.classList.add('animate-spin')
    }

    await Promise.all([
      this.refreshStatistics(),
      this.refreshActivityFeed()
    ])

    if (this.hasRefreshIconTarget) {
      setTimeout(() => {
        this.refreshIconTarget.classList.remove('animate-spin')
      }, 500)
    }
  }

  async refreshStatistics() {
    try {
      const response = await fetch('/settings/routing/statistics', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (response.ok) {
        const stats = await response.json()
        this.updateStatisticsDisplay(stats)
      }
    } catch (error) {
      console.error('Failed to refresh statistics:', error)
    }
  }

  async refreshActivityFeed() {
    if (this.hasActivityFeedTarget) {
      const frame = this.activityFeedTarget
      if (frame.reload) {
        frame.reload()
      } else {
        // Fallback: manually trigger a reload by setting src
        const currentSrc = frame.src || window.location.href
        frame.src = currentSrc
      }
    }
  }

  updateStatisticsDisplay(stats) {
    // Update DOM with new statistics
    // This updates the statistics cards with new values
    if (this.hasStatisticsCardsTarget) {
      const cards = this.statisticsCardsTarget.querySelectorAll('.text-2xl')
      if (cards[0]) cards[0].textContent = stats.llm.total
      if (cards[1]) cards[1].textContent = stats.mcp.total
      if (cards[2]) cards[2].textContent = `${stats.llm.avg_latency}ms`
      if (cards[3]) cards[3].textContent = stats.llm.total_tokens.toLocaleString()
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
