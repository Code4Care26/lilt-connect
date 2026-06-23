<script setup>
import { computed } from 'vue'
import { ICONS } from './icons'

// Thin wrapper so we can render any registered Lucide icon by its name string —
// handy for data-driven glyphs (event posters, status banners) where the icon
// comes from the store/seed. Falls back to a circle for unknown names.
// Only icons listed in ./icons.js are bundled (keeps the build tree-shaken).
const props = defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: 20 },
  strokeWidth: { type: [Number, String], default: 2 },
  color: { type: String, default: 'currentColor' },
})

const component = computed(() => ICONS[props.name] || ICONS.Circle)
</script>

<template>
  <component :is="component" :size="Number(size)" :stroke-width="Number(strokeWidth)" :color="color" />
</template>
