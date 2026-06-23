<script setup>
import { useRouter } from 'vue-router'
import { useVolunteerStore } from '../stores/volunteer'
import LucideIcon from '../components/ui/LucideIcon.vue'
import VolunteerDropOutSheet from '../components/VolunteerDropOutSheet.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'

// Frame 3 of the volunteer design: the volunteer's own applications grouped by
// status (approved → pending → waitlist → supporter), each with its action.
const router = useRouter()
const store = useVolunteerStore()
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex flex-none items-start justify-between border-b border-line bg-white px-5 pb-3.5 pt-1.5">
      <div>
        <div class="text-[22px] font-bold leading-none tracking-tight text-ink">I miei eventi</div>
        <div class="mt-1 text-[12.5px] font-medium text-muted">Stato delle tue candidature come volontario</div>
      </div>
      <button
        class="mt-1 flex h-9 w-9 flex-none items-center justify-center rounded-full bg-[#F1F5F9] text-muted transition-colors hover:bg-line"
        title="Stati dell'adesione"
        @click="router.push('/volunteer/states')"
      >
        <LucideIcon name="Info" :size="18" :stroke-width="2" />
      </button>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <div class="flex flex-col gap-3">
        <div
          v-for="ev in store.myApplications"
          :key="ev.id"
          class="rounded-2xl border border-line bg-white p-3 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]"
        >
          <div class="flex gap-3.5">
            <div class="flex h-[58px] w-[58px] flex-none items-center justify-center rounded-xl" :style="{ background: ev.poster }">
              <LucideIcon :name="ev.icon" :size="26" :stroke-width="1.6" color="#fff" class="opacity-85" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-[15px] font-bold leading-tight tracking-tight text-ink">{{ ev.title }}</div>
              <div class="mt-1.5 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="Calendar" :size="13" color="#94A3B8" />
                {{ ev.dateLabel }} · {{ ev.timeLabel }}
              </div>
              <div
                v-if="ev.chip && !ev.isCancelled"
                class="mt-2.5 inline-flex h-6 items-center gap-1.5 rounded-full px-2.5"
                :style="{ background: ev.chip.bg, border: `1px solid ${ev.chip.border}` }"
              >
                <LucideIcon :name="ev.chip.icon" :size="13" :stroke-width="2.2" :color="ev.chip.fg" />
                <span class="text-[11px] font-semibold leading-none" :style="{ color: ev.chip.fg }">{{ ev.chip.label }}</span>
              </div>
            </div>
          </div>

          <!-- Cancelled: show the reason, no actions (you applied, but it's off). -->
          <EventCancelledBanner v-if="ev.isCancelled" class="mt-3" :reason="ev.reason" />

          <template v-else>
          <button
            v-if="ev.canWithdraw"
            class="mt-3 h-[38px] w-full cursor-pointer rounded-[10px] border border-[#CBD5E1] bg-white text-[12.5px] font-semibold text-muted transition-colors hover:bg-canvas"
            @click="store.withdraw(ev.id)"
          >
            Ritira adesione
          </button>
          <button
            v-else-if="ev.stApproved"
            class="mt-3 h-[38px] w-full cursor-pointer rounded-[10px] border border-[#FECACA] bg-white text-[12.5px] font-semibold text-[#DC2626] transition-colors hover:border-[#FCA5A5] hover:bg-[#FEF2F2]"
            @click="store.askDropOut(ev.id)"
          >
            Tira pacco · rinuncia
          </button>
          <button
            v-else-if="ev.stSupporter"
            class="mt-3 h-[38px] w-full cursor-pointer rounded-[10px] border border-[#CBD5E1] bg-white text-[12.5px] font-semibold text-muted transition-colors hover:bg-canvas"
            @click="store.cancelSupporter(ev.id)"
          >
            Annulla partecipazione
          </button>
          <button
            v-else-if="ev.stWithdrawn"
            class="mt-3 h-[38px] w-full cursor-pointer rounded-[10px] bg-brand text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
            @click="store.applyAsVolunteer(ev.id)"
          >
            Candidati di nuovo
          </button>
          </template>
        </div>

        <p v-if="store.myApplications.length === 0" class="py-10 text-center text-sm text-faint">
          Non hai ancora adesioni. Esplora gli eventi e candidati come volontario.
        </p>
      </div>
    </div>

    <VolunteerDropOutSheet />
  </div>
</template>
