<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import LucideIcon from './LucideIcon.vue'
import { useSessionStore } from '../../stores/session'

// Per-role bottom navigation (decision C). Each role gets its own tab set; only
// Staff is implemented in this step. The managed event (e1) is the candidature
// entry point, mirroring the design.
const route = useRoute()
const router = useRouter()
const session = useSessionStore()

// Profilo is intentionally NOT a tab — it's reached by tapping the avatar in
// the top header (classic pattern). Keep only the primary destinations here.
const NAVS = {
  staff: [
    { key: 'events', label: 'Eventi', icon: 'Calendar', to: '/events', active: ['events', 'new-event'] },
    { key: 'applications', label: 'Candidature', icon: 'Users', to: '/events/e1/applications', active: ['applications'] },
    { key: 'console', label: 'Console', icon: 'LayoutDashboard', to: '/console', active: ['console'] },
  ],
  volunteer: [
    { key: 'events', label: 'Eventi', icon: 'Calendar', to: '/volunteer/events', active: ['volunteer-events', 'volunteer-event'] },
    { key: 'applications', label: 'I miei eventi', icon: 'CalendarCheck', to: '/volunteer/applications', active: ['volunteer-applications', 'volunteer-states'] },
  ],
  supporter: [
    { key: 'events', label: 'Eventi', icon: 'Calendar', to: '/supporter/events', active: ['supporter-events', 'supporter-event'] },
    { key: 'mine', label: 'I miei eventi', icon: 'CalendarCheck', to: '/supporter/mine', active: ['supporter-mine'] },
  ],
}

const items = computed(() => NAVS[session.role] || [])
const isActive = (item) => item.active.includes(route.name)
</script>

<template>
  <!-- Pinned to the shell's bottom edge. min-height keeps the 74px tap row and
       adds the iOS home-indicator inset on top; the matching pb pushes the icons
       up off the indicator so nothing is obscured on notched devices. -->
  <nav
    class="absolute inset-x-0 bottom-0 flex min-h-[calc(74px+env(safe-area-inset-bottom))] items-start justify-around border-t border-line bg-white/90 pt-[11px] pb-[env(safe-area-inset-bottom)] backdrop-blur-md"
  >
    <button
      v-for="item in items"
      :key="item.key"
      class="flex cursor-pointer flex-col items-center gap-1 bg-transparent"
      :style="{ color: isActive(item) ? '#0D9488' : '#94A3B8' }"
      @click="router.push(item.to)"
    >
      <LucideIcon :name="item.icon" :size="23" :stroke-width="isActive(item) ? 2.2 : 2" />
      <span class="text-[11px]" :class="isActive(item) ? 'font-semibold' : 'font-medium'">{{ item.label }}</span>
    </button>
  </nav>
</template>
