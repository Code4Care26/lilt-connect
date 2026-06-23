<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStaffStore } from '../stores/staff'
import LucideIcon from '../components/ui/LucideIcon.vue'

// Frame 4 of the design: create an event as a draft or publish it directly.
// Prefilled with the design's example so the form reads as designed, but every
// field is editable. The same form doubles as the "Modifica" screen: when an
// `id` is routed in, it loads that event and saves with PATCH instead.
const props = defineProps({ id: { type: String, default: '' } })
const router = useRouter()
const store = useStaffStore()

const editing = computed(() => !!props.id)

const TYPES = ['Sensibilizzazione', 'Raccolta fondi', 'Evento solidale']

const title = ref('Open day prevenzione')
const type = ref('Sensibilizzazione')
// `dateISO` (yyyy-mm-dd, from the native date picker) is the source of truth for
// the event's real start: the human `dateLabel` and the backend `startsAt` are
// both derived from it. `time` is HH:MM from the time picker.
const dateISO = ref('2026-07-12')
const time = ref('10:00')
const place = ref('Piazza Garibaldi, Padova')
const description = ref(
  'Giornata di screening e informazione. Cerchiamo volontari per accoglienza e distribuzione materiale.',
)
const volunteers = ref(8)
// Approved volunteers already on the event — preserved across an edit so the
// capacity math (min = approved + available) stays correct.
const approved = ref(0)
// Original label, kept as a fallback when editing an event that has no real
// `startsAt` (so the date picker is empty and we must not blank its label).
const origDateLabel = ref('')

const dec = () => (volunteers.value = Math.max(0, volunteers.value - 1))
const inc = () => (volunteers.value += 1)

// "2026-07-12" -> "Sab 12 lug": the short Italian label shown across the app.
function labelFromIso(iso) {
  if (!iso) return ''
  const d = new Date(`${iso}T00:00:00`)
  if (Number.isNaN(d.getTime())) return ''
  const s = d.toLocaleDateString('it-IT', { weekday: 'short', day: 'numeric', month: 'short' })
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// Combine date + time into the ISO start the backend stores (naive local — the
// prototype has no timezone handling). Null when no date is set.
function startsAtFrom(iso, t) {
  return iso ? `${iso}T${t || '00:00'}:00` : null
}

// Load the event into the form when editing (fetching the list first if the
// store is cold, e.g. when the edit URL is opened directly).
onMounted(async () => {
  if (!editing.value) return
  if (!store.eventById(props.id)) await store.load()
  const ev = store.eventById(props.id)
  if (!ev) return router.replace('/events')
  title.value = ev.title || ''
  type.value = ev.kind || TYPES[0]
  origDateLabel.value = ev.dateLabel || ''
  // Prefill the pickers from the real start when present; otherwise leave the
  // date empty (older events created before startsAt was captured).
  dateISO.value = ev.startsAt ? ev.startsAt.slice(0, 10) : ''
  time.value = ev.startsAt ? ev.startsAt.slice(11, 16) : ''
  place.value = ev.place || ''
  description.value = ev.description || ''
  approved.value = ev.slots?.approved || 0
  volunteers.value = ev.slots?.available || 0
})

async function save(publish) {
  const hasDate = !!dateISO.value
  const data = {
    title: title.value.trim() || 'Nuovo evento',
    kind: type.value,
    place: place.value.trim(),
    // Derive the display label from the picked date; fall back to the original
    // label only when editing an event that still has no real date.
    dateLabel: hasDate ? labelFromIso(dateISO.value) : origDateLabel.value,
    timeLabel: time.value,
    description: description.value.trim(),
    // Only send a real start when a date is picked, so we never clobber an
    // existing startsAt with null on a label-only edit.
    ...(hasDate ? { startsAt: startsAtFrom(dateISO.value, time.value) } : {}),
    // "Volontari richiesti" is the minimum the volunteer badge derives from
    // (minParticipants = approved + available); the requested count is the
    // available slots. A fresh event has 0 approved.
    slots: { approved: editing.value ? approved.value : 0, available: volunteers.value },
  }
  if (editing.value) {
    await store.updateEvent(props.id, data)
  } else {
    await store.createEvent(data, { publish })
  }
  router.push('/events')
}
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex flex-none items-center gap-3 border-b border-line bg-white px-[18px] py-3.5">
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="router.push('/events')"
      >
        <LucideIcon name="X" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
      <div class="text-[17px] font-bold tracking-tight text-ink">{{ editing ? 'Modifica evento' : 'Nuovo evento' }}</div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-[18px] pb-[calc(150px+env(safe-area-inset-bottom))] pt-[18px]">
      <!-- Title -->
      <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Titolo</label>
      <input
        v-model="title"
        class="mb-4 h-12 w-full rounded-xl border border-[#CBD5E1] px-3.5 text-sm font-medium text-ink outline-none focus:border-brand"
      />

      <!-- Type -->
      <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Tipo di evento</label>
      <div class="mb-4 flex flex-wrap gap-1.5">
        <button
          v-for="t in TYPES"
          :key="t"
          class="inline-flex h-[34px] cursor-pointer items-center rounded-full px-3.5 text-[12.5px] transition-colors"
          :class="type === t ? 'bg-brand font-semibold text-white' : 'border border-line bg-white font-medium text-muted'"
          @click="type = t"
        >
          {{ t }}
        </button>
      </div>

      <!-- Date + time -->
      <div class="mb-4 flex gap-3">
        <div class="flex-1">
          <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Data</label>
          <div class="flex h-12 items-center gap-2 rounded-xl border border-[#CBD5E1] px-3.5">
            <LucideIcon name="Calendar" :size="16" color="#94A3B8" />
            <input v-model="dateISO" type="date" class="w-full bg-transparent text-sm font-medium text-ink outline-none" />
          </div>
        </div>
        <div class="flex-1">
          <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Orario</label>
          <div class="flex h-12 items-center gap-2 rounded-xl border border-[#CBD5E1] px-3.5">
            <LucideIcon name="Clock" :size="16" color="#94A3B8" />
            <input v-model="time" type="time" class="w-full bg-transparent text-sm font-medium text-ink outline-none" />
          </div>
        </div>
      </div>

      <!-- Place -->
      <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Luogo</label>
      <div class="mb-4 flex h-12 items-center gap-2 rounded-xl border border-[#CBD5E1] px-3.5">
        <LucideIcon name="MapPin" :size="16" color="#94A3B8" />
        <input v-model="place" class="w-full bg-transparent text-sm font-medium text-ink outline-none" />
      </div>

      <!-- Description -->
      <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Descrizione</label>
      <textarea
        v-model="description"
        rows="3"
        class="mb-4 min-h-[84px] w-full resize-none rounded-xl border border-[#CBD5E1] px-3.5 py-3 text-[13.5px] leading-relaxed text-[#475569] outline-none focus:border-brand"
      />

      <!-- Volunteers needed -->
      <label class="mb-1.5 block text-[13px] font-semibold leading-tight text-[#334155]">Volontari richiesti</label>
      <div class="flex h-12 items-center justify-between rounded-xl border border-[#CBD5E1] pl-3.5 pr-1.5">
        <span class="text-[15px] font-semibold text-ink">{{ volunteers }}</span>
        <div class="flex gap-1.5">
          <button class="flex h-9 w-9 items-center justify-center rounded-[9px] bg-[#F1F5F9] text-[#475569]" @click="dec">
            <LucideIcon name="Minus" :size="16" :stroke-width="2.4" />
          </button>
          <button class="flex h-9 w-9 items-center justify-center rounded-[9px] bg-[#F1F5F9] text-[#475569]" @click="inc">
            <LucideIcon name="Plus" :size="16" :stroke-width="2.4" />
          </button>
        </div>
      </div>

      <div v-if="!editing" class="mt-4 flex items-center gap-2.5 rounded-xl bg-[#F1F5F9] px-3.5 py-3">
        <LucideIcon name="Info" :size="18" color="#64748B" class="flex-none" />
        <div class="text-xs leading-relaxed text-muted">
          Salvando come <b class="text-ink">bozza</b> l'evento non è visibile ai volontari finché non lo pubblichi.
        </div>
      </div>
    </div>

    <!-- Sticky action bar -->
    <div
      class="absolute inset-x-0 bottom-0 flex gap-2.5 px-[18px] pb-[calc(26px+env(safe-area-inset-bottom))] pt-3.5"
      style="background: linear-gradient(to top, #f8fafc 72%, rgba(248, 250, 252, 0))"
    >
      <template v-if="editing">
        <button
          class="h-[52px] w-full cursor-pointer rounded-[13px] bg-brand text-[14.5px] font-bold text-white shadow-[0_8px_24px_-8px_rgba(20,184,166,.45)] transition-colors hover:bg-brand-dark"
          @click="save()"
        >
          Salva modifiche
        </button>
      </template>
      <template v-else>
        <button
          class="h-[52px] flex-1 cursor-pointer rounded-[13px] border border-[#CBD5E1] bg-white text-sm font-semibold text-[#334155] transition-colors hover:bg-[#F1F5F9]"
          @click="save(false)"
        >
          Salva bozza
        </button>
        <button
          class="h-[52px] flex-[1.1] cursor-pointer rounded-[13px] bg-brand text-[14.5px] font-bold text-white shadow-[0_8px_24px_-8px_rgba(20,184,166,.45)] transition-colors hover:bg-brand-dark"
          @click="save(true)"
        >
          Pubblica
        </button>
      </template>
    </div>
  </div>
</template>
