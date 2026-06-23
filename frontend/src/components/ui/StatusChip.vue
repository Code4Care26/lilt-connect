<script setup>
import LucideIcon from './LucideIcon.vue'

// Small status pill (event lifecycle: bozza / pubblicato / annullato, etc.).
// Colours are passed in so the same chip serves any status.
defineProps({
  label: { type: String, required: true },
  bg: { type: String, default: '#F1F5F9' },
  border: { type: String, default: '#E2E8F0' },
  fg: { type: String, default: '#475569' },
  icon: { type: String, default: '' },
})
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 rounded-full px-2.5"
    :style="{ height: '22px', background: bg, border: `1px solid ${border}` }"
  >
    <LucideIcon v-if="icon" :name="icon" :size="12" :stroke-width="2.3" :color="fg" />
    <span class="text-[10px] font-bold leading-none" :style="{ color: fg }">{{ label }}</span>
  </span>
</template>
