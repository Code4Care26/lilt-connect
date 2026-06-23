<script setup>
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { useVolunteerStore } from '../stores/volunteer'
import LucideIcon from '../components/ui/LucideIcon.vue'
import Avatar from '../components/ui/Avatar.vue'
import VolunteerDropOutSheet from '../components/VolunteerDropOutSheet.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'

// Frame 1 of the volunteer design: the public events stream. Each event offers
// a dual action (participate as supporter / apply as volunteer) and, once you
// have a status, the contextual action (withdraw / drop out).
const router = useRouter()
const session = useSessionStore()
const store = useVolunteerStore()

const openDetail = (id) => router.push(`/volunteer/events/${id}`)
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
        <span class="inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#99F6E4] bg-brand-tint px-2.5">
          <LucideIcon name="ShieldCheck" :size="13" :stroke-width="2.2" color="#0F766E" />
          <span class="text-[11px] font-bold leading-none text-brand-dark">Volontario</span>
        </span>
        <button class="cursor-pointer" title="Profilo" @click="router.push('/volunteer/profile')">
          <Avatar :initials="session.currentUser.initials" :color="session.currentUser.color" />
        </button>
      </div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <div class="mx-1 mb-3.5 text-[19px] font-bold tracking-tight text-ink">Eventi vicino a te</div>
      <div class="flex flex-col gap-3">
        <div
          v-for="ev in store.stream"
          :key="ev.id"
          class="rounded-2xl border border-line bg-white p-3 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]"
        >
          <div class="flex cursor-pointer gap-3.5" @click="openDetail(ev.id)">
            <div class="flex h-[74px] w-[74px] flex-none items-center justify-center overflow-hidden rounded-xl" :style="{ background: ev.poster }">
              <LucideIcon :name="ev.icon" :size="32" :stroke-width="1.6" color="#fff" class="opacity-85" />
            </div>
            <div class="min-w-0 flex-1">
              <span class="text-[10px] font-semibold uppercase tracking-wide text-brand">{{ ev.kind }}</span>
              <div class="mt-1 text-[15px] font-bold leading-tight tracking-tight text-ink">{{ ev.title }}</div>
              <div class="mt-1.5 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="Calendar" :size="13" color="#94A3B8" />
                {{ ev.dateLabel }}
              </div>
              <div class="mt-1 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="MapPin" :size="13" color="#94A3B8" />
                {{ ev.place }}
              </div>
            </div>
          </div>

          <!-- Cancelled: visible to everyone with its reason, no actions. -->
          <EventCancelledBanner v-if="ev.isCancelled" class="mt-2.5" :reason="ev.reason" />

          <template v-else>
          <!-- status chip -->
          <div
            v-if="ev.chip"
            class="mt-2.5 inline-flex h-[26px] items-center gap-1.5 rounded-full px-2.5"
            :style="{ background: ev.chip.bg, border: `1px solid ${ev.chip.border}` }"
          >
            <LucideIcon :name="ev.chip.icon" :size="13" :stroke-width="2.2" :color="ev.chip.fg" />
            <span class="text-[11px] font-semibold leading-none" :style="{ color: ev.chip.fg }">{{ ev.chip.label }}</span>
          </div>

          <!-- "ingaggio" badge: event still below its minimum participants -->
          <div
            v-if="ev.engagement"
            class="mt-2.5 inline-flex h-[26px] items-center gap-1.5 rounded-full px-2.5"
            :style="{ background: ev.engagement.bg, border: `1px solid ${ev.engagement.border}` }"
          >
            <LucideIcon :name="ev.engagement.icon" :size="13" :stroke-width="2.2" :color="ev.engagement.fg" />
            <span class="text-[11px] font-semibold leading-none" :style="{ color: ev.engagement.fg }">{{ ev.engagement.label }}</span>
          </div>

          <!-- actions -->
          <!-- A withdrawn volunteer may re-apply, so it offers the same dual action as a fresh event. -->
          <div v-if="ev.stNone || ev.stWithdrawn" class="mt-3 flex gap-2">
            <button
              class="h-[42px] flex-1 cursor-pointer rounded-xl border border-[#CBD5E1] bg-white text-[12.5px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
              @click="store.participateAsSupporter(ev.id)"
            >
              Partecipa
            </button>
            <button
              class="h-[42px] flex-[1.4] cursor-pointer rounded-xl bg-brand text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
              @click="store.applyAsVolunteer(ev.id)"
            >
              {{ ev.stWithdrawn ? 'Candidati di nuovo' : 'Aderisci come volontario' }}
            </button>
          </div>

          <div v-else-if="ev.stSupporter" class="mt-3 flex gap-2">
            <button
              class="flex h-[42px] w-[42px] flex-none items-center justify-center rounded-xl border border-line bg-white text-muted transition-colors hover:border-[#FECACA] hover:bg-[#FEF2F2] hover:text-[#DC2626]"
              @click="store.cancelSupporter(ev.id)"
            >
              <LucideIcon name="X" :size="17" :stroke-width="2.2" />
            </button>
            <button
              class="h-[42px] flex-1 cursor-pointer rounded-xl bg-brand text-[12.5px] font-semibold text-white transition-colors hover:bg-brand-dark"
              @click="store.applyAsVolunteer(ev.id)"
            >
              Aderisci come volontario
            </button>
          </div>

          <button
            v-else-if="ev.canWithdraw"
            class="mt-3 h-[42px] w-full cursor-pointer rounded-xl border border-[#CBD5E1] bg-white text-[12.5px] font-semibold text-muted transition-colors hover:bg-canvas"
            @click="store.withdraw(ev.id)"
          >
            Ritira adesione
          </button>

          <button
            v-else-if="ev.stApproved"
            class="mt-3 h-[42px] w-full cursor-pointer rounded-xl border border-[#FECACA] bg-white text-[12.5px] font-semibold text-[#DC2626] transition-colors hover:border-[#FCA5A5] hover:bg-[#FEF2F2]"
            @click="store.askDropOut(ev.id)"
          >
            Rinuncia
          </button>
          </template>
        </div>
      </div>
    </div>

    <VolunteerDropOutSheet />
  </div>
</template>
