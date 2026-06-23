<script setup>
import BottomSheet from './ui/BottomSheet.vue'
import LucideIcon from './ui/LucideIcon.vue'

// Guest-only sheet shown after tapping "Partecipa" without being logged in.
// Offers an optional login or continuing as a guest (decision M).
defineProps({ open: { type: Boolean, default: false } })
const emit = defineEmits(['login', 'guest', 'close'])
</script>

<template>
  <BottomSheet :open="open" @close="emit('close')">
    <div class="mb-3.5 flex h-[52px] w-[52px] items-center justify-center rounded-[14px] bg-brand-tint">
      <LucideIcon name="Bell" :size="26" :stroke-width="2" color="#0D9488" />
    </div>
    <div class="text-[19px] font-bold leading-tight tracking-tight text-ink">Accedi per seguire l'evento</div>
    <p class="my-2 mb-[18px] text-[13.5px] leading-relaxed text-muted">
      Con un account ricevi gli aggiornamenti dallo staff e ritrovi le tue adesioni in "I miei eventi". Puoi anche dare
      la disponibilità come ospite.
    </p>
    <button
      class="mb-2.5 h-[50px] w-full cursor-pointer rounded-[13px] bg-brand text-[15px] font-bold text-white transition-colors hover:bg-brand-dark"
      @click="emit('login')"
    >
      Accedi o registrati
    </button>
    <button
      class="h-[50px] w-full cursor-pointer rounded-[13px] border border-line bg-white text-sm font-semibold text-[#334155] transition-colors hover:bg-canvas"
      @click="emit('guest')"
    >
      Continua come ospite
    </button>
  </BottomSheet>
</template>
