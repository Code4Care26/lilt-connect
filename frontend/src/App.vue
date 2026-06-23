<script setup>
import { computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BottomNav from './components/ui/BottomNav.vue'
import Toast from './components/ui/Toast.vue'
import InstallPrompt from './components/ui/InstallPrompt.vue'
import { useSessionStore } from './stores/session'
import { useStaffStore } from './stores/staff'
import { useVolunteerStore } from './stores/volunteer'
import { useSupporterStore } from './stores/supporter'
import { connectStream, disconnectStream } from './api/stream'
import { useAppUpdate } from './composables/useAppUpdate'

// AppShell: a single mobile-first PWA. The active role comes from the logged-in
// identity (resolved by the backend); only that role's store is loaded, and it
// reloads when the identity changes (login/logout). The URL is kept in sync
// with the active role so router-view never shows another role's screens.
const session = useSessionStore()
const stores = {
  staff: useStaffStore(),
  volunteer: useVolunteerStore(),
  supporter: useSupporterStore(),
}
const route = useRoute()
const router = useRouter()

const hideNav = computed(() => route.meta.hideNav === true)

// Home route per role.
const HOME = { staff: '/events', volunteer: '/volunteer/events', supporter: '/supporter/events' }

// If the current route doesn't belong to the active role, jump to that role's
// home — so a role switch never leaves another role's screen mounted.
function syncRouteToRole(role) {
  const home = HOME[role]
  if (home && route.meta.role !== role) router.replace(home)
}

// (Re)load the data for the active role only. Forced on every identity change
// because the backend serves role- and identity-scoped data.
function loadActiveRole() {
  return (stores[session.role] || stores.supporter).load()
}

// Realtime (SSE): the backend pushes invalidation messages; we react by
// re-syncing through the same load() path used on login. A short debounce
// coalesces a burst of invalidations (e.g. a reset, or several decisions) into
// a single re-fetch.
let reloadTimer = null
function onRealtime() {
  clearTimeout(reloadTimer)
  reloadTimer = setTimeout(() => {
    loadActiveRole()
    // Staff only: if a "manage applications" screen is open, its applicant rows
    // don't come back through loadActiveRole() — refresh them explicitly.
    const staff = stores.staff
    if (session.role === 'staff' && staff.managedEventId) staff.loadApplicants(staff.managedEventId)
  }, 120)
}

// (Re)open the SSE stream for the current identity. connectStream() closes any
// previous connection, so this is safe to call on every identity change.
function openStream() {
  connectStream(session.name, onRealtime)
}

// Register the service worker and wire its update lifecycle to a toast: a new
// build surfaces an "Aggiorna" prompt instead of self-activating silently.
useAppUpdate()

// Make the persisted identity travel on the very first request.
session.hydrate()

// A change of identity (login/logout) flips the role and the visible data, and
// re-points the realtime stream at the new identity.
watch(
  () => [session.name, session.role].join('|'),
  () => {
    loadActiveRole()
    syncRouteToRole(session.role)
    openStream()
  },
)

onMounted(async () => {
  loadActiveRole()
  openStream()
  // Wait for the router to resolve the initial route, otherwise route.meta is
  // still empty and we'd wrongly bounce a deep-linked sub-page to the role home.
  await router.isReady()
  syncRouteToRole(session.role)
})

onUnmounted(() => {
  clearTimeout(reloadTimer)
  disconnectStream()
})
</script>

<template>
  <!-- App shell: locked to the *dynamic* viewport height (100dvh) so it always
       matches the visible area as the mobile browser toolbar shows/hides, and
       overflow-hidden so the page itself never scrolls — only <main> does. This
       is what keeps the top header and bottom nav pinned like a native app. -->
  <div class="flex h-dvh flex-col items-center overflow-hidden bg-[#E7E5DF]">
    <!-- Phone column: full width on mobile, centred column on wider screens. -->
    <div class="relative flex h-full w-full max-w-[420px] flex-col overflow-hidden bg-canvas shadow-[0_30px_50px_-16px_rgba(15,23,42,.18)] sm:my-2 sm:h-[calc(100dvh-1rem)] sm:rounded-[28px]">
      <!-- All three roles run on the router; the active role's home is enforced. -->
      <main class="scrl relative flex-1 overflow-y-auto">
        <router-view />
      </main>
      <BottomNav v-if="!hideNav" />
      <Toast />
      <InstallPrompt />
    </div>
  </div>
</template>
