<script setup>
import LucideIcon from './ui/LucideIcon.vue'
import { useUiStore } from '../stores/ui'
import { copyToClipboard, eventAddressText, downloadEventIcs } from '../lib/eventExport'

// The date + place card shared by the volunteer and supporter event details.
// Each row carries a discrete action on the right: copy the address, or save
// the date as an .ics. Kept in one component so both views stay in sync.
const props = defineProps({ ev: { type: Object, required: true } })
const ui = useUiStore()

async function onCopyAddress() {
  const text = eventAddressText(props.ev)
  if (!text) return
  const ok = await copyToClipboard(text)
  ui.showToast(ok ? 'Indirizzo copiato' : 'Impossibile copiare', ok ? 'ok' : 'error')
}

function onDownloadIcs() {
  const ok = downloadEventIcs(props.ev)
  ui.showToast(ok ? 'Evento salvato (.ics)' : 'Data non disponibile', ok ? 'ok' : 'error')
}
</script>

<template>
  <div class="flex flex-col gap-px overflow-hidden rounded-2xl border border-line bg-white">
    <!-- date: action saves an .ics to add to the user's calendar -->
    <div class="flex items-center gap-3 border-b border-[#F1F5F9] px-[15px] py-3.5">
      <LucideIcon name="Calendar" :size="20" color="#0D9488" />
      <div class="min-w-0 flex-1">
        <div class="text-sm font-semibold text-ink">{{ ev.dateLabel }}</div>
        <div class="text-xs text-muted">{{ ev.timeLabel }}</div>
      </div>
      <button
        v-if="ev.startsAt"
        type="button"
        class="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-lg text-brand transition-colors hover:bg-brand-tint active:bg-[#CCFBF1]"
        aria-label="Aggiungi al calendario"
        title="Aggiungi al calendario"
        @click="onDownloadIcs"
      >
        <LucideIcon name="Download" :size="18" color="#0D9488" />
      </button>
    </div>

    <!-- place: action copies the full address to the clipboard -->
    <div class="flex items-center gap-3 px-[15px] py-3.5">
      <LucideIcon name="MapPin" :size="20" color="#0D9488" />
      <div class="min-w-0 flex-1">
        <div class="text-sm font-semibold text-ink">{{ ev.place }}</div>
        <div class="text-xs text-muted">{{ ev.address }}</div>
      </div>
      <button
        v-if="ev.place || ev.address"
        type="button"
        class="flex h-9 w-9 flex-none cursor-pointer items-center justify-center rounded-lg text-brand transition-colors hover:bg-brand-tint active:bg-[#CCFBF1]"
        aria-label="Copia indirizzo"
        title="Copia indirizzo"
        @click="onCopyAddress"
      >
        <LucideIcon name="Copy" :size="18" color="#0D9488" />
      </button>
    </div>
  </div>
</template>
