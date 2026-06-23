<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useVolunteerStore } from '../stores/volunteer'
import LucideIcon from '../components/ui/LucideIcon.vue'
import VolunteerDropOutSheet from '../components/VolunteerDropOutSheet.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'
import EventDetailMeta from '../components/EventDetailMeta.vue'
import EventShareButton from '../components/EventShareButton.vue'

// Frame 2 of the volunteer design: full event detail with a sticky CTA that
// reflects the volunteer's current application status.
const props = defineProps({ id: { type: String, required: true } })
const router = useRouter()
const store = useVolunteerStore()

const ev = computed(() => store.eventById(props.id))
const back = () => router.push('/volunteer/events')
</script>

<template>
  <div v-if="ev" class="flex h-full flex-col">
    <div class="scrl flex-1 overflow-y-auto pb-[calc(150px+env(safe-area-inset-bottom))]">
      <!-- Hero -->
      <div class="relative h-[230px]" :style="{ background: ev.poster }">
        <div class="absolute inset-0 flex items-center justify-center opacity-20">
          <LucideIcon :name="ev.icon" :size="112" :stroke-width="1.3" color="#fff" />
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

        <!-- Cancelled: shown to everyone with its reason; the roles block and the
             sticky CTA below are hidden so the event offers no actions. -->
        <EventCancelledBanner v-if="ev.isCancelled" class="mt-4" :reason="ev.reason" />

        <!-- date + place, each with its export action (copy address / save .ics) -->
        <EventDetailMeta :ev="ev" class="my-4" />

        <!-- volunteer roles -->
        <div v-if="!ev.isCancelled" class="mb-[18px] rounded-2xl border border-[#CCFBF1] bg-brand-tint px-4 py-[15px]">
          <div class="mb-2.5 flex items-center gap-2">
            <LucideIcon name="ShieldCheck" :size="18" color="#0F766E" />
            <span class="text-sm font-bold text-[#115E59]">Cerchiamo volontari</span>
          </div>
          <p class="mb-3 text-[13px] leading-relaxed text-[#115E59]">
            Ruolo attivo durante l'evento. L'adesione viene valutata dallo staff: riceverai l'esito in app.
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="role in ev.roles"
              :key="role"
              class="inline-flex h-7 items-center rounded-lg border border-[#99F6E4] bg-white px-2.5 text-xs font-semibold text-brand-dark"
            >
              {{ role }}
            </span>
          </div>
          <div class="mt-3 flex items-center gap-1.5 text-xs font-medium text-brand-dark">
            <LucideIcon name="Users" :size="14" color="#0F766E" />
            {{ ev.slots.approved }} volontari approvati · {{ ev.slots.available }} posti ancora disponibili
          </div>

          <!-- "ingaggio" badge: event still below its minimum participants -->
          <div
            v-if="ev.engagement"
            class="mt-3 inline-flex h-[26px] items-center gap-1.5 rounded-full px-2.5"
            :style="{ background: ev.engagement.bg, border: `1px solid ${ev.engagement.border}` }"
          >
            <LucideIcon :name="ev.engagement.icon" :size="13" :stroke-width="2.2" :color="ev.engagement.fg" />
            <span class="text-[11px] font-semibold leading-none" :style="{ color: ev.engagement.fg }">{{ ev.engagement.label }}</span>
          </div>
        </div>

        <div class="mb-2 text-[15px] font-bold text-ink">Descrizione</div>
        <p class="text-sm leading-relaxed text-[#475569]">{{ ev.description }}</p>
      </div>
    </div>

    <!-- sticky CTA (hidden on a cancelled event: nothing to do) -->
    <div
      v-if="!ev.isCancelled"
      class="absolute inset-x-0 bottom-0 flex flex-col gap-2.5 px-[18px] pb-[calc(26px+env(safe-area-inset-bottom))] pt-3.5"
      style="background: linear-gradient(to top, #f8fafc 72%, rgba(248, 250, 252, 0))"
    >
      <div
        v-if="ev.chip"
        class="flex items-center gap-2.5 rounded-xl px-3 py-3"
        :style="{ background: ev.chip.bg, border: `1px solid ${ev.chip.border}` }"
      >
        <LucideIcon :name="ev.chip.icon" :size="18" :stroke-width="2.2" :color="ev.chip.fg" />
        <div class="text-[13px] font-semibold leading-snug" :style="{ color: ev.chip.fg }">{{ ev.chip.banner }}</div>
      </div>

      <div v-if="ev.stNone" class="flex gap-2.5">
        <button
          class="h-[52px] flex-1 cursor-pointer rounded-[13px] border border-[#CBD5E1] bg-white text-[13.5px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
          @click="store.participateAsSupporter(ev.id)"
        >
          Partecipa come sostenitore
        </button>
        <button
          class="h-[52px] flex-[1.2] cursor-pointer rounded-[13px] bg-brand text-[13.5px] font-bold text-white shadow-[0_8px_24px_-8px_rgba(20,184,166,.45)] transition-colors hover:bg-brand-dark"
          @click="store.applyAsVolunteer(ev.id)"
        >
          Aderisci come volontario
        </button>
      </div>
      <button
        v-else-if="ev.stSupporter"
        class="h-[52px] w-full cursor-pointer rounded-[13px] bg-brand text-[15px] font-bold text-white transition-colors hover:bg-brand-dark"
        @click="store.applyAsVolunteer(ev.id)"
      >
        Aderisci come volontario
      </button>
      <button
        v-else-if="ev.canWithdraw"
        class="h-[52px] w-full cursor-pointer rounded-[13px] border border-[#CBD5E1] bg-white text-[14.5px] font-semibold text-muted transition-colors hover:bg-canvas"
        @click="store.withdraw(ev.id)"
      >
        Ritira adesione
      </button>
      <button
        v-else-if="ev.stApproved"
        class="h-[52px] w-full cursor-pointer rounded-[13px] border border-[#FECACA] bg-white text-[14.5px] font-semibold text-[#DC2626] transition-colors hover:border-[#FCA5A5] hover:bg-[#FEF2F2]"
        @click="store.askDropOut(ev.id)"
      >
        Rinuncia all'evento
      </button>
    </div>

    <VolunteerDropOutSheet />
  </div>
</template>
