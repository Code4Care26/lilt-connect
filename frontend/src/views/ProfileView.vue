<script setup>
import { useRouter } from 'vue-router'
import { useStaffStore } from '../stores/staff'
import { useSessionStore } from '../stores/session'
import Avatar from '../components/ui/Avatar.vue'
import LucideIcon from '../components/ui/LucideIcon.vue'

// Staff profile. Reached by tapping the avatar in the header (not a tab), so it
// has a back button. Also hosts the demo data reset (decision G).
const router = useRouter()
const store = useStaffStore()
const session = useSessionStore()

function switchUser() {
  session.logout()
  router.push('/supporter/login')
}
</script>

<template>
  <div class="flex h-full flex-col">
    <header class="flex flex-none items-center gap-3 border-b border-line bg-white px-[18px] pb-3.5 pt-3.5">
      <button
        class="flex h-[38px] w-[38px] flex-none cursor-pointer items-center justify-center rounded-full bg-[#F1F5F9]"
        @click="router.push('/events')"
      >
        <LucideIcon name="ChevronLeft" :size="20" :stroke-width="2.2" color="#0F172A" />
      </button>
      <div class="text-[19px] font-bold tracking-tight text-ink">Profilo</div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-[18px] pb-[calc(96px+env(safe-area-inset-bottom))] pt-6">
      <div class="flex flex-col items-center text-center">
        <Avatar initials="RB" color="#4338CA" :size="72" />
        <div class="mt-3 text-lg font-bold tracking-tight text-ink">Roberto Bianchi</div>
        <div class="mt-0.5 text-sm font-medium text-muted">Coordinatore · LILT Padova</div>
        <span class="mt-3 inline-flex h-[26px] items-center gap-1.5 rounded-full border border-[#C7D2FE] bg-[#EEF2FF] px-2.5">
          <LucideIcon name="ShieldCheck" :size="13" :stroke-width="2.2" color="#4338CA" />
          <span class="text-[11px] font-bold leading-none text-[#4338CA]">{{ session.roleLabel }}</span>
        </span>
      </div>

      <div class="mt-8 rounded-2xl border border-line bg-white p-4">
        <div class="text-[13px] font-semibold text-ink">Dati demo</div>
        <p class="mt-1 text-xs leading-relaxed text-muted">
          Risincronizza se la schermata sembra disallineata: ricarica i dati dal server, senza perdere nulla. «Ripristina dati demo» riporta invece tutto allo stato iniziale.
        </p>
        <button
          class="mt-3 flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-[#99F6E4] bg-[#F0FDFA] text-[13px] font-semibold text-[#0F766E] transition-colors hover:bg-[#CCFBF1]"
          @click="store.resync()"
        >
          <LucideIcon name="RefreshCw" :size="16" :stroke-width="2.2" />
          Risincronizza
        </button>
        <button
          class="mt-2 flex h-11 w-full items-center justify-center gap-2 rounded-xl border border-line bg-white text-[13px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
          @click="store.resetData()"
        >
          <LucideIcon name="RotateCcw" :size="16" :stroke-width="2.2" />
          Ripristina dati demo
        </button>
      </div>

      <button
        class="mt-4 flex h-11 w-full cursor-pointer items-center justify-center gap-2 rounded-xl border border-line bg-white text-[13px] font-semibold text-[#334155] transition-colors hover:bg-canvas"
        @click="switchUser"
      >
        <LucideIcon name="LogOut" :size="16" :stroke-width="2.2" />
        Cambia utente
      </button>
    </div>
  </div>
</template>
