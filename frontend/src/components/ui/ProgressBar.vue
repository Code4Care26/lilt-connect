<script setup>
// Capacity bar (approved volunteers / requested). pct is 0–100.
defineProps({
  pct: { type: Number, default: 0 },
  color: { type: String, default: '#0D9488' },
  track: { type: String, default: '#F1F5F9' },
})
</script>

<template>
  <div class="h-2 overflow-hidden rounded-full" :style="{ background: track }">
    <div
      class="h-full rounded-full transition-[width] duration-300"
      :style="{ width: Math.max(0, Math.min(100, pct)) + '%', background: color }"
    />
  </div>
</template>
