import { useRegisterSW } from 'virtual:pwa-register/vue'
import { useUiStore } from '../stores/ui'

// PWA update flow (registerType: 'prompt' — see vite.config.js + sw.js).
//
// vite-plugin-pwa's useRegisterSW registers the service worker and exposes the
// lifecycle as callbacks:
//  - onNeedRefresh: a new build is installed and *waiting*. We surface a
//    persistent "Aggiorna" toast; tapping it runs updateServiceWorker(true),
//    which posts SKIP_WAITING to the waiting SW and reloads on controllerchange.
//  - onOfflineReady: the app shell is cached and usable offline — a one-shot,
//    auto-dismissing info toast (no action).
//
// Call once from the app root (App.vue) inside setup, with pinia active.
export function useAppUpdate() {
  const ui = useUiStore()

  const { updateServiceWorker } = useRegisterSW({
    onNeedRefresh() {
      ui.showActionToast('Nuova versione disponibile', 'info', {
        label: 'Aggiorna',
        run: () => updateServiceWorker(true),
      })
    },
    onOfflineReady() {
      ui.showToast("App pronta per l'uso offline", 'info')
    },
  })

  return { updateServiceWorker }
}
