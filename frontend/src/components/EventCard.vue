<script setup>
import LucideIcon from './ui/LucideIcon.vue'
import StatusChip from './ui/StatusChip.vue'

// One event in the Staff list. Stateless: it renders a decorated event from the
// store and emits intent (publish / manage / cancel) — the view wires those to
// store actions. Action set depends on the event's lifecycle state.
defineProps({
  event: { type: Object, required: true },
})
defineEmits(['publish', 'manage', 'cancel', 'edit'])
</script>

<template>
  <div class="rounded-2xl border border-line bg-white p-3 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]">
    <div class="flex gap-3.5">
      <div
        class="flex h-16 w-16 flex-none items-center justify-center overflow-hidden rounded-xl"
        :style="{ background: event.poster }"
      >
        <LucideIcon :name="event.icon" :size="28" :stroke-width="1.6" color="#fff" class="opacity-85" />
      </div>
      <div class="min-w-0 flex-1">
        <StatusChip
          class="mb-1.5"
          :label="event.chip.label"
          :bg="event.chip.bg"
          :border="event.chip.border"
          :fg="event.chip.fg"
        />
        <div class="text-[15px] font-bold leading-tight tracking-tight text-ink">{{ event.title }}</div>
        <div class="mt-1.5 flex items-center gap-1.5 text-xs font-medium leading-tight text-muted">
          <LucideIcon name="Calendar" :size="13" color="#94A3B8" />
          {{ event.dateLabel }} · {{ event.place }}
        </div>
      </div>
    </div>

    <!-- secondary status banner -->
    <div class="mt-2.5 flex items-center gap-2 rounded-[10px] px-3 py-2.5" :style="{ background: event.stat.bg }">
      <LucideIcon :name="event.stat.icon" :size="14" :color="event.stat.fg" />
      <span class="text-xs font-medium leading-snug" :style="{ color: event.stat.fg }">{{ event.stat.text }}</span>
    </div>

    <!-- draft -->
    <div v-if="event.isDraft" class="mt-2.5 flex gap-2">
      <button
        class="flex h-[42px] w-11 flex-none items-center justify-center rounded-xl border border-line bg-white text-muted transition-colors hover:bg-canvas"
        @click="$emit('edit', event)"
      >
        <LucideIcon name="PencilLine" :size="17" />
      </button>
      <button
        class="flex h-[42px] flex-1 items-center justify-center gap-1.5 rounded-xl bg-brand text-[13px] font-semibold text-white transition-colors hover:bg-brand-dark"
        @click="$emit('publish', event)"
      >
        <LucideIcon name="ArrowRight" :size="16" :stroke-width="2.2" color="#fff" />
        Pubblica
      </button>
    </div>

    <!-- published -->
    <div v-else-if="event.isPublished" class="mt-2.5 flex gap-2">
      <button
        class="h-[42px] flex-1 rounded-xl border border-[#99F6E4] bg-white text-[12.5px] font-semibold text-brand-dark transition-colors hover:bg-brand-tint"
        @click="$emit('manage', event)"
      >
        Gestisci candidature
      </button>
      <button
        class="h-[42px] flex-none rounded-xl border border-[#FECACA] bg-white px-3.5 text-[12.5px] font-semibold text-[#DC2626] transition-colors hover:border-[#FCA5A5] hover:bg-[#FEF2F2]"
        @click="$emit('cancel', event)"
      >
        Annulla
      </button>
    </div>

    <!-- cancelled -->
    <div v-else-if="event.isCancelled" class="mt-2.5 text-xs font-medium italic leading-snug text-faint">
      Evento annullato · volontari avvisati
    </div>
  </div>
</template>
