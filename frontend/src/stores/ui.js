import { defineStore } from 'pinia'

// Shared UI state. The transient confirmation toast lives here so every role's
// store (staff, volunteer, …) can emit one and a single <Toast> renders it.
let timer = null

export const useUiStore = defineStore('ui', {
  state: () => ({
    toast: null, // { text, tone, action? } | null
  }),

  actions: {
    showToast(text, tone = 'ok') {
      this.toast = { text, tone }
      clearTimeout(timer)
      timer = setTimeout(() => {
        this.toast = null
      }, 3000)
    },
    // Persistent, actionable toast (no auto-dismiss): stays until the user taps
    // the action or it's cleared. `action` is { label, run } — <Toast> renders a
    // button that invokes run(). Used by the PWA "new version available" flow.
    // Cancels any pending auto-dismiss so a leftover 3s timer can't kill it.
    showActionToast(text, tone = 'info', action = null) {
      clearTimeout(timer)
      this.toast = { text, tone, action }
    },
    clearToast() {
      clearTimeout(timer)
      this.toast = null
    },
  },
})
