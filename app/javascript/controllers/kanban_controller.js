import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["board", "column", "cardList", "newColumnForm", "newCardForm"]

  connect() {
    this.setupDragAndDrop()
  }

  setupDragAndDrop() {
    // Make cards draggable
    this.element.querySelectorAll('[data-card-id]').forEach(card => {
      card.addEventListener('dragstart', this.handleDragStart.bind(this))
      card.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    // Make card lists droppable
    this.cardListTargets.forEach(list => {
      list.addEventListener('dragover', this.handleDragOver.bind(this))
      list.addEventListener('drop', this.handleDrop.bind(this))
      list.addEventListener('dragleave', this.handleDragLeave.bind(this))
    })
  }

  handleDragStart(event) {
    const card = event.target.closest('[data-card-id]')
    if (!card) return

    this.draggedCard = card
    card.classList.add('opacity-50')
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', card.dataset.cardId)
  }

  handleDragEnd(event) {
    const card = event.target.closest('[data-card-id]')
    if (card) {
      card.classList.remove('opacity-50')
    }
    this.draggedCard = null

    // Remove all drop indicators
    document.querySelectorAll('.drop-indicator').forEach(el => el.remove())
    document.querySelectorAll('[data-kanban-target="cardList"]').forEach(el => {
      el.classList.remove('bg-blue-50')
    })
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'

    const cardList = event.target.closest('[data-kanban-target="cardList"]')
    if (cardList) {
      cardList.classList.add('bg-blue-50')
    }
  }

  handleDragLeave(event) {
    const cardList = event.target.closest('[data-kanban-target="cardList"]')
    if (cardList && !cardList.contains(event.relatedTarget)) {
      cardList.classList.remove('bg-blue-50')
    }
  }

  handleDrop(event) {
    event.preventDefault()

    const cardId = event.dataTransfer.getData('text/plain')
    const cardList = event.target.closest('[data-kanban-target="cardList"]')

    if (!cardList || !cardId) return

    const columnId = cardList.dataset.columnId
    const cards = Array.from(cardList.querySelectorAll('[data-card-id]'))
    let position = cards.length

    // Find insertion position based on drop location
    const dropY = event.clientY
    for (let i = 0; i < cards.length; i++) {
      const rect = cards[i].getBoundingClientRect()
      if (dropY < rect.top + rect.height / 2) {
        position = i
        break
      }
    }

    // Move the card in the DOM
    if (this.draggedCard) {
      if (position < cards.length) {
        cardList.insertBefore(this.draggedCard, cards[position])
      } else {
        cardList.appendChild(this.draggedCard)
      }
    }

    // Send update to server
    this.moveCard(cardId, columnId, position)

    cardList.classList.remove('bg-blue-50')
  }

  async moveCard(cardId, columnId, position) {
    const boardId = this.element.querySelector('[data-board-id]')?.dataset.boardId ||
                    window.location.pathname.match(/\/boards\/(\d+)/)?.[1]

    if (!boardId) return

    const csrfToken = document.querySelector('[name="csrf-token"]')?.content

    try {
      const response = await fetch(`/boards/${boardId}/cards/${cardId}/move`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          column_id: columnId,
          position: position
        })
      })

      if (!response.ok) {
        console.error('Failed to move card')
        // Optionally refresh the page to restore correct state
      }
    } catch (error) {
      console.error('Error moving card:', error)
    }
  }

  showNewColumnForm() {
    if (this.hasNewColumnFormTarget) {
      this.newColumnFormTarget.classList.remove('hidden')
    }
  }

  hideNewColumnForm() {
    if (this.hasNewColumnFormTarget) {
      this.newColumnFormTarget.classList.add('hidden')
    }
  }

  showNewCardForm(event) {
    const columnId = event.currentTarget.dataset.columnId
    const form = this.element.querySelector(`[data-kanban-target="newCardForm"][data-column-id="${columnId}"]`)
    if (form) {
      form.classList.remove('hidden')
      form.querySelector('input[type="text"]')?.focus()
    }
  }

  hideNewCardForm(event) {
    const columnId = event.currentTarget.dataset.columnId
    const form = this.element.querySelector(`[data-kanban-target="newCardForm"][data-column-id="${columnId}"]`)
    if (form) {
      form.classList.add('hidden')
    }
  }

  showCardDetail(event) {
    // Don't trigger if clicking on a button or dragging
    if (event.target.closest('button') || event.target.closest('a')) return

    const card = event.currentTarget
    const cardId = card.dataset.cardId
    const boardId = window.location.pathname.match(/\/boards\/(\d+)/)?.[1]

    if (cardId && boardId) {
      // Load card details via Turbo
      const drawer = document.getElementById('card-drawer')
      const content = document.getElementById('card-drawer-content')

      if (drawer && content) {
        drawer.classList.remove('hidden')
        content.innerHTML = '<div class="flex items-center justify-center h-full"><p class="text-gray-500">Loading...</p></div>'

        fetch(`/boards/${boardId}/cards/${cardId}`, {
          headers: {
            'Accept': 'text/html'
          }
        })
        .then(response => response.text())
        .then(html => {
          content.innerHTML = html
        })
        .catch(error => {
          console.error('Error loading card:', error)
          content.innerHTML = '<div class="p-4 text-red-500">Failed to load card details</div>'
        })
      }
    }
  }
}
