import { defineStore } from 'pinia'

// Installability state for the PWA. We intercept Chromium's
// `beforeinstallprompt` so the app — not the browser's random mini-infobar —
// decides WHEN to offer installation: only after a key action (the first
// volunteer candidatura, see stores/volunteer.applyAsVolunteer → arm()).
//
// iOS Safari never fires `beforeinstallprompt`, so on iOS `canInstall` stays
// false and the custom button never appears; there the user installs via
// "Aggiungi a schermata Home" (the Apple meta tags in index.html make that
// result run standalone).

// Already running as an installed app? Chrome/Android: display-mode media query;
// iOS Safari: the non-standard navigator.standalone. Guarded so the store loads
// in jsdom (specs), where matchMedia may be absent.
function detectStandalone() {
  if (typeof window === 'undefined') return false
  const mql = window.matchMedia && window.matchMedia('(display-mode: standalone)')
  return !!(mql && mql.matches) || window.navigator?.standalone === true
}

export const usePwaStore = defineStore('pwa', {
  state: () => ({
    deferredPrompt: null, // captured BeforeInstallPromptEvent (Chromium only)
    armed: false, // flipped on by a key action; gates the custom button
    dismissed: false, // user closed the banner this session
    installed: false, // set on appinstalled / accepted prompt
    standalone: detectStandalone(),
  }),

  getters: {
    // Technically installable right now: we hold a usable prompt event and the
    // app isn't already installed/standalone.
    canInstall: (state) => !!state.deferredPrompt && !state.installed && !state.standalone,
    // Whether to actually render the custom "Installa app" affordance: only once
    // armed by a key action and not dismissed.
    showInstallButton() {
      return this.armed && !this.dismissed && this.canInstall
    },
  },

  actions: {
    // Wire the browser events once, at app startup (main.js).
    init() {
      if (typeof window === 'undefined') return
      window.addEventListener('beforeinstallprompt', (e) => this.capturePrompt(e))
      window.addEventListener('appinstalled', () => this.onInstalled())
    },

    // Stash the event and stop Chrome's own infobar so we control the timing.
    capturePrompt(event) {
      event.preventDefault()
      this.deferredPrompt = event
    },

    onInstalled() {
      this.installed = true
      this.deferredPrompt = null
    },

    // Trigger gate: surface the offer after a meaningful action.
    arm() {
      this.armed = true
    },

    dismiss() {
      this.dismissed = true
    },

    // Fire the native install dialog. The event is single-use, so we drop it
    // afterwards regardless of outcome. Returns 'accepted' | 'dismissed' | null.
    async promptInstall() {
      const evt = this.deferredPrompt
      if (!evt) return null
      evt.prompt()
      const choice = await evt.userChoice
      this.deferredPrompt = null
      const outcome = choice ? choice.outcome : null
      if (outcome === 'accepted') this.installed = true
      return outcome
    },
  },
})
