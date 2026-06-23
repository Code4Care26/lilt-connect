<script setup>
import { useSupporterStore } from '../stores/supporter'
import LucideIcon from '../components/ui/LucideIcon.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'

// Frame 3 of the supporter design: the events the supporter has signed up for.
const store = useSupporterStore()
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex-none border-b border-line bg-white px-5 pb-3.5 pt-1.5">
      <div class="text-[22px] font-bold leading-none tracking-tight text-ink">I miei eventi</div>
      <div class="mt-1 text-[12.5px] font-medium text-muted">Le iniziative a cui hai dato la disponibilità</div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <div v-if="store.myEvents.length" class="flex flex-col gap-3">
        <div
          v-for="ev in store.myEvents"
          :key="ev.id"
          class="rounded-2xl border border-line bg-white p-3 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]"
        >
          <div class="flex gap-3.5">
            <div class="flex h-[62px] w-[62px] flex-none items-center justify-center rounded-xl" :style="{ background: ev.poster }">
              <LucideIcon :name="ev.icon" :size="28" :stroke-width="1.6" color="#fff" class="opacity-85" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-[15px] font-bold leading-tight tracking-tight text-ink">{{ ev.title }}</div>
              <div class="mt-1.5 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="Calendar" :size="13" color="#94A3B8" />
                {{ ev.dateLabel }} · {{ ev.timeLabel }}
              </div>
              <div v-if="!ev.isCancelled" class="mt-2.5 inline-flex h-6 items-center gap-1.5 rounded-full border border-[#FDE68A] bg-[#FFFBEB] px-2.5">
                <LucideIcon name="Clock" :size="13" :stroke-width="2.2" color="#D97706" />
                <span class="text-[11px] font-semibold leading-none text-[#B45309]">Inviata allo staff · in attesa</span>
              </div>
            </div>
          </div>
          <!-- Cancelled: show the reason, no actions. -->
          <EventCancelledBanner v-if="ev.isCancelled" class="mt-3" :reason="ev.reason" />
          <button
            v-else
            class="mt-3 h-[38px] w-full cursor-pointer rounded-[10px] border border-line bg-white text-[12.5px] font-semibold text-muted transition-colors hover:border-[#FECACA] hover:bg-[#FEF2F2] hover:text-[#DC2626]"
            @click="store.leave(ev.id)"
          >
            Annulla partecipazione
          </button>
        </div>
      </div>

      <div v-else class="flex flex-col items-center px-8 pt-16 text-center">
        <div class="mb-[18px] flex h-[76px] w-[76px] items-center justify-center rounded-full bg-[#F1F5F9]">
          <LucideIcon name="Calendar" :size="36" :stroke-width="1.8" color="#94A3B8" />
        </div>
        <div class="text-[17px] font-bold tracking-tight text-ink">Non partecipi a nessun evento</div>
        <p class="mt-2 text-[13.5px] leading-relaxed text-muted">
          Sfoglia gli eventi pubblici e aderisci a quelli che ti interessano.
        </p>
      </div>
    </div>
  </div>
</template>
