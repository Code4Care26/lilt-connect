<script setup>
import { computed } from 'vue'
import LucideIcon from './LucideIcon.vue'

// Transient confirmation toast. Reads the current toast from the shared ui
// store, so any role can produce one. Tone maps to an icon + accent colour.
import { useUiStore } from '../../stores/ui'
const ui = useUiStore()

const TONES = {
  ok: { bg: '#0D9488', icon: 'Check' },
  publish: { bg: '#15803D', icon: 'Check' },
  info: { bg: '#1D4ED8', icon: 'Info' },
  danger: { bg: '#DC2626', icon: 'X' },
}

const toast = computed(() => ui.toast)
const tone = computed(() => TONES[toast.value?.tone] || TONES.ok)
const action = computed(() => toast.value?.action || null)

// Run the action and dismiss the toast (the action — e.g. updateServiceWorker —
// typically reloads the page anyway, so clearing first keeps the UI honest).
function runAction() {
  const run = action.value?.run
  ui.clearToast()
  run?.()
}
</script>

<template>
  <div
    v-if="toast"
    class="anim-toast absolute bottom-[88px] left-1/2 z-50 flex w-[336px] -translate-x-1/2 items-start gap-2.5 rounded-2xl bg-ink px-4 py-3"
    style="box-shadow: 0 16px 30px -10px rgba(15, 23, 42, 0.5)"
  >
    <div class="flex h-[26px] w-[26px] flex-none items-center justify-center rounded-full" :style="{ background: tone.bg }">
      <LucideIcon :name="tone.icon" :size="15" :stroke-width="2.6" color="#fff" />
    </div>
    <div class="flex-1 self-center text-[13px] font-medium leading-snug text-canvas">{{ toast.text }}</div>
    <button
      v-if="action"
      type="button"
      class="flex-none self-center rounded-full bg-canvas px-3 py-1 text-[12px] font-semibold text-ink transition active:scale-95"
      @click="runAction"
    >
      {{ action.label }}
    </button>
  </div>
</template>
