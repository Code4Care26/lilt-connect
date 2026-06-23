<script setup>
// Initials avatar with a per-person colour. Never shows a photo or contact
// info — aligns with the privacy-by-design constraint (identity, not contacts).
defineProps({
  initials: { type: String, required: true },
  color: { type: String, default: '#0D9488' },
  size: { type: Number, default: 40 },
})
</script>

<template>
  <div
    class="flex flex-none items-center justify-center rounded-full font-bold text-white"
    :style="{ width: size + 'px', height: size + 'px', background: color, fontSize: Math.round(size * 0.34) + 'px' }"
  >
    {{ initials }}
  </div>
</template>
