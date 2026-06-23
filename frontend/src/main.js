import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { usePwaStore } from './stores/pwa'
import './style.css'

const app = createApp(App)
app.use(createPinia()).use(router)

// Register the install-prompt listeners before mounting, so a `beforeinstallprompt`
// that fires during startup is captured rather than lost.
usePwaStore().init()

app.mount('#app')
