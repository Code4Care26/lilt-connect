<script setup>
// Reusable bottom sheet: dimmed scrim + slide-up panel, used for the cancel
// reason flow and reusable by other roles later. Closes on scrim click.
defineProps({
  open: { type: Boolean, default: false },
})
const emit = defineEmits(['close'])
</script>

<template>
  <div v-if="open" class="absolute inset-0 z-40">
    <div class="anim-scrim absolute inset-0 bg-[rgba(15,23,42,.45)]" @click="emit('close')" />
    <div
      class="anim-sheet absolute inset-x-0 bottom-0 rounded-t-3xl bg-white px-5 pt-2 pb-6"
      style="box-shadow: 0 -12px 40px -12px rgba(15, 23, 42, 0.25)"
    >
      <div class="mx-auto mb-4 mt-1.5 h-1 w-10 rounded-full bg-line" />
      <slot />
    </div>
  </div>
</template>
