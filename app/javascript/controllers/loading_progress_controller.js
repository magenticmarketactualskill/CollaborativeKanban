import { Controller } from "@hotwired/stimulus"

// Handles progressive loading states during LLM operations
// Cycles through tips to keep UI feeling responsive during delays
export default class extends Controller {
  static targets = ["tip"]
  static values = {
    current: { type: Number, default: 0 },
    theme: { type: String, default: "blue" }
  }

  // Tips that cycle during loading to keep the UI feeling alive
  analysisTips = [
    "AI is analyzing your card content...",
    "Evaluating complexity and estimating effort...",
    "Identifying potential blockers...",
    "Generating actionable subtasks...",
    "Almost there, finalizing analysis..."
  ]

  suggestionTips = [
    "AI is reviewing your card for improvements...",
    "Looking for ways to enhance clarity...",
    "Checking for missing details...",
    "Generating actionable suggestions...",
    "Polishing recommendations..."
  ]

  connect() {
    this.tipIndex = 0

    // Start tip cycling with smooth transitions
    this.tipInterval = setInterval(() => this.cycleTip(), 3500)

    // Add a subtle pulse effect to skeleton elements
    this.pulseInterval = setInterval(() => this.pulseSkeleton(), 2000)
  }

  disconnect() {
    if (this.tipInterval) clearInterval(this.tipInterval)
    if (this.pulseInterval) clearInterval(this.pulseInterval)
  }

  cycleTip() {
    if (!this.hasTipTarget) return

    const tips = this.themeValue === 'yellow' ? this.suggestionTips : this.analysisTips
    this.tipIndex = (this.tipIndex + 1) % tips.length

    // Smooth fade transition
    this.tipTarget.style.transition = 'opacity 0.3s ease-out'
    this.tipTarget.style.opacity = '0'

    setTimeout(() => {
      this.tipTarget.textContent = tips[this.tipIndex]
      this.tipTarget.style.opacity = '1'
    }, 300)
  }

  pulseSkeleton() {
    // Add a brief scale effect to show activity
    const skeletons = this.element.querySelectorAll('[class*="animate-pulse"]')
    skeletons.forEach((skeleton, index) => {
      setTimeout(() => {
        skeleton.style.transition = 'transform 0.2s ease-out'
        skeleton.style.transform = 'scale(1.01)'
        setTimeout(() => {
          skeleton.style.transform = 'scale(1)'
        }, 200)
      }, index * 50)
    })
  }
}
