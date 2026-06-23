<script setup>
import LucideIcon from './ui/LucideIcon.vue'

// Shown on a cancelled event across every non-staff surface (volunteer/supporter
// stream + detail). A cancelled event stays visible to everyone, with its reason,
// regardless of role or participation — and offers no actions (you can't join or
// apply to it). Colours match the staff cancelled chip (STATUS_META.cancelled).
defineProps({
  reason: { type: String, default: '' },
})
</script>

<template>
  <div class="flex items-start gap-2 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2.5">
    <LucideIcon name="TriangleAlert" :size="16" :stroke-width="2.2" color="#DC2626" class="mt-px flex-none" />
    <div class="min-w-0">
      <div class="text-[12.5px] font-bold leading-tight text-[#DC2626]">Evento annullato</div>
      <div v-if="reason" class="mt-0.5 text-[11.5px] font-medium leading-snug text-[#B91C1C]">Causa: {{ reason }}</div>
    </div>
  </div>
</template>
