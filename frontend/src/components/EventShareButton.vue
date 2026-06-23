<script setup>
import LucideIcon from './ui/LucideIcon.vue'
import { useUiStore } from '../stores/ui'
import { shareEvent } from '../lib/eventExport'

// The round "share" button that floats over the event hero. Uses the native
// share sheet where available and silently copies the summary otherwise — the
// toast only fires when there's something worth telling the user.
const props = defineProps({ ev: { type: Object, required: true } })
const ui = useUiStore()

async function onShare() {
  const result = await shareEvent(props.ev)
  if (result === 'copied') ui.showToast('Dettagli copiati: incollali dove vuoi', 'ok')
  else if (result === 'failed') ui.showToast('Condivisione non riuscita', 'error')
  // 'shared' / 'cancelled': the OS share sheet already gave its own feedback
}
</script>

<template>
  <button
    type="button"
    class="absolute right-[18px] top-[52px] flex h-[38px] w-[38px] cursor-pointer items-center justify-center rounded-full bg-white/90 transition-colors hover:bg-white"
    aria-label="Condividi evento"
    title="Condividi evento"
    @click="onShare"
  >
    <LucideIcon name="Share2" :size="19" :stroke-width="2.2" color="#0F172A" />
  </button>
</template>
