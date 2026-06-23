<script setup>
import LucideIcon from './LucideIcon.vue'
import { usePwaStore } from '../../stores/pwa'

// Custom "Installa app" banner. Mirrors the Toast look (dark ink card, canvas
// text) but is anchored to the top so it doesn't collide with the bottom
// Toast/BottomNav. Visibility is fully driven by the pwa store: it only shows on
// Chromium, after a key action (arm()), when not already installed/dismissed —
// so on iOS or an installed app this renders nothing.
const pwa = usePwaStore()

async function install() {
  await pwa.promptInstall()
}
</script>

<template>
  <div
    v-if="pwa.showInstallButton"
    class="anim-banner absolute left-3 right-3 top-3 z-50 flex items-center gap-3 rounded-2xl bg-ink px-3.5 py-3"
    style="box-shadow: 0 16px 30px -10px rgba(15, 23, 42, 0.5)"
  >
    <div class="flex h-9 w-9 flex-none items-center justify-center rounded-full bg-brand">
      <LucideIcon name="ShieldCheck" :size="19" :stroke-width="2.4" color="#fff" />
    </div>
    <div class="min-w-0 flex-1">
      <div class="text-[13px] font-semibold leading-tight text-canvas">Installa LILT sul telefono</div>
      <div class="text-[11px] leading-tight text-canvas/70">Accesso rapido dalla schermata Home</div>
    </div>
    <button
      class="flex flex-none items-center gap-1.5 rounded-full bg-brand px-3 py-1.5 text-[12px] font-semibold text-white"
      @click="install"
    >
      <LucideIcon name="Download" :size="14" :stroke-width="2.6" />
      Installa
    </button>
    <button class="flex-none p-1 text-canvas/60" aria-label="Chiudi" @click="pwa.dismiss()">
      <LucideIcon name="X" :size="16" :stroke-width="2.4" />
    </button>
  </div>
</template>
