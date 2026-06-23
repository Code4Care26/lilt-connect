<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useStaffStore } from '../stores/staff'
import EventCard from '../components/EventCard.vue'
import LucideIcon from '../components/ui/LucideIcon.vue'
import BottomSheet from '../components/ui/BottomSheet.vue'

// Frame 1 of the design: the event list with publish/cancel actions, plus the
// cancel-reason bottom sheet (frame 3) rendered on top.
const store = useStaffStore()
const router = useRouter()

const FILTERS = [
  { key: 'all', label: 'Tutti' },
  { key: 'draft', label: 'Bozze' },
  { key: 'published', label: 'Pubblicati' },
  { key: 'cancelled', label: 'Annullati' },
]
const filter = ref('all')

const events = computed(() =>
  filter.value === 'all' ? store.decoratedEvents : store.decoratedEvents.filter((e) => e.status === filter.value),
)

const goManage = (ev) => router.push(`/events/${ev.id}/applications`)
const goEdit = (ev) => router.push(`/events/${ev.id}/edit`)
</script>

<template>
  <div class="flex h-full flex-col">
    <!-- Brand header -->
    <header class="flex flex-none items-center justify-between border-b border-line bg-white px-[18px] pb-3.5 pt-1.5">
      <div class="flex flex-col gap-px">
        <span class="text-[26px] font-extrabold leading-none tracking-wide text-lilt">LILT</span>
        <span class="text-xs font-medium leading-tight tracking-wide text-muted">gocciolina</span>
      </div>
      <div class="flex items-center gap-2.5">
        <span class="inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#C7D2FE] bg-[#EEF2FF] px-2.5">
          <LucideIcon name="ShieldCheck" :size="13" :stroke-width="2.2" color="#4338CA" />
          <span class="text-[11px] font-bold leading-none text-[#4338CA]">Staff</span>
        </span>
        <button
          class="flex h-10 w-10 cursor-pointer items-center justify-center rounded-full bg-[#4338CA] text-sm font-bold text-white"
          title="Profilo"
          @click="router.push('/profile')"
        >
          RB
        </button>
      </div>
    </header>

    <!-- Title + new -->
    <div class="flex flex-none items-center justify-between px-[18px] pb-2.5 pt-4">
      <div class="text-[19px] font-bold tracking-tight text-ink">Eventi</div>
      <button
        class="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-full bg-brand px-3.5 text-[13px] font-semibold text-white transition-colors hover:bg-brand-dark"
        @click="router.push('/events/new')"
      >
        <LucideIcon name="Plus" :size="16" :stroke-width="2.4" color="#fff" />
        Nuovo
      </button>
    </div>

    <!-- Filters -->
    <div class="flex flex-none gap-1.5 px-[18px] pb-2">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        class="inline-flex h-[30px] cursor-pointer items-center rounded-full px-3 text-xs transition-colors"
        :class="
          filter === f.key
            ? 'bg-ink font-semibold text-white'
            : 'border border-line bg-white font-medium text-muted hover:bg-canvas'
        "
        @click="filter = f.key"
      >
        {{ f.label }}
      </button>
    </div>

    <!-- List -->
    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-2.5">
      <div class="flex flex-col gap-3">
        <EventCard
          v-for="ev in events"
          :key="ev.id"
          :event="ev"
          @publish="store.publish($event.id)"
          @manage="goManage"
          @edit="goEdit"
          @cancel="store.openCancel($event.id)"
        />
        <p v-if="events.length === 0" class="py-10 text-center text-sm text-faint">Nessun evento in questa vista.</p>
      </div>
    </div>

    <!-- Cancel reason sheet (frame 3) -->
    <BottomSheet :open="store.cancelOpen" @close="store.closeCancel">
      <div class="text-[19px] font-bold leading-tight tracking-tight text-ink">Annulla "{{ store.cancelTitle }}"</div>
      <p class="my-2 mb-4 text-[13px] leading-relaxed text-muted">
        Indica la causa. I volontari iscritti riceveranno una notifica con il motivo.
      </p>
      <div class="mb-[18px] flex flex-col gap-2">
        <button
          v-for="r in store.reasons"
          :key="r"
          class="flex h-12 w-full cursor-pointer items-center justify-between rounded-xl px-3.5"
          :style="
            store.cancelChoice === r
              ? { border: '1.5px solid #0D9488', background: '#F0FDFA' }
              : { border: '1px solid #E2E8F0', background: '#fff' }
          "
          @click="store.setCancelChoice(r)"
        >
          <span class="text-[13.5px] font-semibold" :style="{ color: store.cancelChoice === r ? '#0F766E' : '#334155' }">{{ r }}</span>
          <LucideIcon v-if="store.cancelChoice === r" name="Check" :size="18" :stroke-width="2.6" color="#0D9488" />
        </button>
      </div>
      <button
        class="mb-2.5 h-[50px] w-full cursor-pointer rounded-[13px] bg-[#DC2626] text-[15px] font-bold text-white transition-colors hover:bg-[#B91C1C]"
        @click="store.confirmCancel"
      >
        Conferma annullamento
      </button>
      <button
        class="h-[50px] w-full cursor-pointer rounded-[13px] border border-line bg-white text-sm font-semibold text-[#334155] transition-colors hover:bg-canvas"
        @click="store.closeCancel"
      >
        Indietro
      </button>
    </BottomSheet>
  </div>
</template>
