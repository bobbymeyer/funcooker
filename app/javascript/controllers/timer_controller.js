import { Controller } from "@hotwired/stimulus"

// Counts down to endsAt, as m:ss, and says so when it is up.
export default class extends Controller {
  static values = { endsAt: String }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const left = Math.round((new Date(this.endsAtValue) - Date.now()) / 1000)
    if (left <= 0) {
      this.element.textContent = "done"
      this.element.classList.add("timer--done")
      clearInterval(this.interval)
    } else {
      const minutes = Math.floor(left / 60)
      const seconds = String(left % 60).padStart(2, "0")
      this.element.textContent = `${minutes}:${seconds}`
    }
  }
}
