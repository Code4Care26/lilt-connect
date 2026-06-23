<script setup>
import { useVolunteerStore } from '../stores/volunteer'
import BottomSheet from './ui/BottomSheet.vue'
import LucideIcon from './ui/LucideIcon.vue'

// Confirmation sheet for "tira pacco" (dropping out of an approved event).
// State lives in the volunteer store, so this can be mounted by any volunteer
// view that triggers a drop-out.
const store = useVolunteerStore()
</script>

<template>
  <BottomSheet :open="store.confirmOpen" @close="store.cancelDropOut">
    <div class="mb-3.5 flex h-[52px] w-[52px] items-center justify-center rounded-[14px] bg-[#FEF2F2]">
      <LucideIcon name="TriangleAlert" :size="26" :stroke-width="2" color="#DC2626" />
    </div>
    <div class="text-[19px] font-bold leading-tight tracking-tight text-ink">Vuoi rinunciare all'evento?</div>
    <p class="my-2 mb-[18px] text-[13.5px] leading-relaxed text-muted">
      Sei un volontario <b class="text-[#15803D]">approvato</b> per "{{ store.confirmTitle }}". Rinunciando liberi il
      tuo posto: lo staff e la lista di riserva verranno avvisati.
    </p>
    <button
      class="mb-2.5 h-[50px] w-full cursor-pointer rounded-[13px] bg-[#DC2626] text-[15px] font-bold text-white transition-colors hover:bg-[#B91C1C]"
      @click="store.confirmDropOut"
    >
      Conferma rinuncia
    </button>
    <button
      class="h-[50px] w-full cursor-pointer rounded-[13px] border border-line bg-white text-sm font-semibold text-[#334155] transition-colors hover:bg-canvas"
      @click="store.cancelDropOut"
    >
      Mantieni l'adesione
    </button>
  </BottomSheet>
</template>
