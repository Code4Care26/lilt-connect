<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { useSupporterStore } from '../stores/supporter'
import LucideIcon from '../components/ui/LucideIcon.vue'
import OptionalLoginSheet from '../components/OptionalLoginSheet.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'
import EventDetailMeta from '../components/EventDetailMeta.vue'
import EventShareButton from '../components/EventShareButton.vue'

// Frame 2 of the supporter design: event detail with a participation CTA.
const props = defineProps({ id: { type: String, required: true } })
const router = useRouter()
const session = useSessionStore()
const store = useSupporterStore()

const ev = computed(() => store.eventById(props.id))
const sheetOpen = ref(false)
const back = () => router.push('/supporter/events')

function onPartecipa() {
  if (session.isGuest) sheetOpen.value = true
  else store.join(props.id)
}
const sheetLogin = () => {
  sheetOpen.value = false
  router.push('/supporter/login')
}
const sheetGuest = () => {
  sheetOpen.value = false
  store.join(props.id, { guest: true })
}
</script>

<template>
  <div v-if="ev" class="flex h-full flex-col">
    <div class="scrl flex-1 overflow-y-auto pb-[calc(120px+env(safe-area-inset-bottom))]">
      <!-- Hero -->
      <div class="relative h-[248px]" :style="{ background: ev.poster }">
        <div class="absolute inset-0 flex items-center justify-center opacity-20">
          <LucideIcon :name="ev.icon" :size="120" :stroke-width="1.3" color="#fff" />
        </div>
        <button
          class="absolute left-[18px] top-[52px] flex h-[38px] w-[38px] cursor-pointer items-center justify-center rounded-full bg-white/90"
          @click="back"
        >
          <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
        </button>
        <EventShareButton :ev="ev" />
        <span class="absolute bottom-4 left-[18px] inline-flex h-[26px] items-center rounded-full bg-white/90 px-3 text-xs font-semibold text-brand-dark">
          {{ ev.kind }}
        </span>
      </div>

      <div class="px-[18px] pt-[18px]">
        <div class="text-[23px] font-bold leading-tight tracking-tight text-ink">{{ ev.title }}</div>
        <div class="mt-1 text-sm font-medium text-brand">{{ ev.subtitle }}</div>

        <!-- Cancelled: shown to everyone with its reason; the hint and the sticky
             CTA below are hidden so the event offers no participation action. -->
        <EventCancelledBanner v-if="ev.isCancelled" class="mt-4" :reason="ev.reason" />

        <!-- date + place, each with its export action (copy address / save .ics) -->
        <EventDetailMeta :ev="ev" class="my-[18px]" />

        <div class="mb-2 text-[15px] font-bold text-ink">Descrizione</div>
        <p class="mb-[18px] text-sm leading-relaxed text-[#475569]">{{ ev.description }}</p>

        <div v-if="!ev.isCancelled" class="flex items-center gap-2.5 rounded-[13px] border border-[#CCFBF1] bg-brand-tint px-3.5 py-3">
          <LucideIcon name="Bell" :size="22" color="#0F766E" class="flex-none" />
          <div class="text-[12.5px] leading-relaxed text-[#115E59]">
            Toccando <b>Partecipa</b> segnali la tua disponibilità: lo staff LILT verrà avvisato.
          </div>
        </div>
      </div>
    </div>

    <!-- sticky CTA (hidden on a cancelled event: nothing to do) -->
    <div
      v-if="!ev.isCancelled"
      class="absolute inset-x-0 bottom-0 flex flex-col gap-2.5 px-[18px] pb-[calc(26px+env(safe-area-inset-bottom))] pt-4"
      style="background: linear-gradient(to top, #f8fafc 70%, rgba(248, 250, 252, 0))"
    >
      <button
        v-if="ev.isJoined && !session.isGuest"
        class="flex h-[52px] w-full cursor-pointer items-center justify-center gap-2 rounded-[13px] border border-[#99F6E4] bg-brand-tint text-[15px] font-semibold text-brand-dark"
        @click="store.leave(ev.id)"
      >
        <LucideIcon name="Check" :size="20" :stroke-width="2.4" color="#0F766E" />
        Partecipi · tocca per annullare
      </button>
      <div
        v-else-if="ev.isJoined"
        class="flex h-[52px] w-full items-center justify-center gap-2 rounded-[13px] border border-[#99F6E4] bg-brand-tint text-[15px] font-semibold text-brand-dark"
      >
        <LucideIcon name="Check" :size="20" :stroke-width="2.4" color="#0F766E" />
        Inviata come ospite
      </div>
      <button
        v-else
        class="h-[52px] w-full cursor-pointer rounded-[13px] bg-brand text-[15px] font-bold text-white shadow-[0_8px_24px_-8px_rgba(20,184,166,.45)] transition-colors hover:bg-brand-dark"
        @click="onPartecipa"
      >
        Partecipa
      </button>
    </div>

    <OptionalLoginSheet :open="sheetOpen" @login="sheetLogin" @guest="sheetGuest" @close="sheetOpen = false" />
  </div>
</template>
