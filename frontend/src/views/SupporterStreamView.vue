<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '../stores/session'
import { useSupporterStore } from '../stores/supporter'
import LucideIcon from '../components/ui/LucideIcon.vue'
import Avatar from '../components/ui/Avatar.vue'
import OptionalLoginSheet from '../components/OptionalLoginSheet.vue'
import EventCancelledBanner from '../components/EventCancelledBanner.vue'

// Frame 1 of the supporter design. Two modes (decision M): guest (login button
// + optional-login sheet on "Partecipa") and logged (bell + avatar, direct
// participation toggle).
const router = useRouter()
const session = useSessionStore()
const store = useSupporterStore()

const sheetEventId = ref(null)
const sheetOpen = ref(false)

const openDetail = (id) => router.push(`/supporter/events/${id}`)

function onPartecipa(id) {
  if (session.isGuest) {
    sheetEventId.value = id
    sheetOpen.value = true
  } else {
    store.join(id)
  }
}
const sheetLogin = () => {
  sheetOpen.value = false
  router.push('/supporter/login')
}
const sheetGuest = () => {
  sheetOpen.value = false
  if (sheetEventId.value) store.join(sheetEventId.value, { guest: true })
}
</script>

<template>
  <div class="flex h-full flex-col">
    <!-- Header -->
    <header class="flex flex-none items-center justify-between border-b border-line bg-white px-[18px] pb-3.5 pt-1.5">
      <div class="flex flex-col gap-px">
        <span class="text-[26px] font-extrabold leading-none tracking-wide text-lilt">LILT</span>
        <span class="text-xs font-medium leading-tight tracking-wide text-muted">gocciolina</span>
      </div>

      <!-- guest: Accedi -->
      <button
        v-if="session.isGuest"
        class="inline-flex h-9 cursor-pointer items-center gap-1.5 rounded-full border border-brand bg-white px-3.5 text-[13px] font-semibold text-brand transition-colors hover:bg-brand-tint"
        @click="router.push('/supporter/login')"
      >
        <LucideIcon name="LogIn" :size="16" :stroke-width="2.2" color="#0D9488" />
        Accedi
      </button>

      <!-- logged: bell + avatar -->
      <div v-else class="flex items-center gap-2.5">
        <div class="relative flex h-[42px] w-[42px] items-center justify-center rounded-full bg-[#F1F5F9] text-[#334155]">
          <LucideIcon name="Bell" :size="21" :stroke-width="2" />
          <span class="absolute right-2.5 top-2 h-2 w-2 rounded-full border-2 border-[#F1F5F9] bg-lilt" />
        </div>
        <button class="cursor-pointer" title="Profilo" @click="router.push('/supporter/profile')">
          <Avatar :initials="session.currentUser.initials" :color="session.currentUser.color" :size="42" />
        </button>
      </div>
    </header>

    <div class="scrl flex-1 overflow-y-auto px-4 pb-[calc(96px+env(safe-area-inset-bottom))] pt-4">
      <!-- guest banner -->
      <div v-if="session.isGuest" class="mb-4 flex items-center gap-2.5 rounded-xl bg-[#F1F5F9] px-3.5 py-3">
        <LucideIcon name="Info" :size="18" color="#64748B" class="flex-none" />
        <div class="text-xs leading-relaxed text-muted">
          Stai esplorando come <b class="text-ink">ospite</b>. Accedi quando vuoi per seguire i tuoi eventi.
        </div>
      </div>

      <div class="mx-1 mb-3.5 text-[19px] font-bold tracking-tight text-ink">Eventi vicino a te</div>
      <div class="flex flex-col gap-3">
        <div
          v-for="ev in store.stream"
          :key="ev.id"
          class="rounded-2xl border border-line bg-white p-3 shadow-[0_1px_3px_0_rgba(15,23,42,.08)]"
        >
          <div class="flex cursor-pointer gap-3.5" @click="openDetail(ev.id)">
            <div class="flex h-[78px] w-[78px] flex-none items-center justify-center overflow-hidden rounded-xl" :style="{ background: ev.poster }">
              <LucideIcon :name="ev.icon" :size="34" :stroke-width="1.6" color="#fff" class="opacity-85" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="mb-1 flex items-center gap-1.5">
                <span class="text-[10px] font-semibold uppercase tracking-wide text-brand">{{ ev.kind }}</span>
                <span class="inline-flex h-[18px] items-center rounded-full px-1.5 text-[10px] font-semibold leading-none" :style="{ background: ev.badgeBg, color: ev.badgeFg }">{{ ev.badge }}</span>
              </div>
              <div class="text-[15px] font-bold leading-tight tracking-tight text-ink">{{ ev.title }}</div>
              <div class="mt-1.5 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="Calendar" :size="13" color="#94A3B8" />
                {{ ev.dateLabel }}
              </div>
              <div class="mt-1 flex items-center gap-1.5 text-xs font-medium text-muted">
                <LucideIcon name="MapPin" :size="13" color="#94A3B8" />
                {{ ev.place }}
              </div>
            </div>
          </div>

          <!-- Cancelled: visible to everyone with its reason, no actions. -->
          <EventCancelledBanner v-if="ev.isCancelled" class="mt-3" :reason="ev.reason" />

          <!-- joined -->
          <template v-else-if="ev.isJoined">
            <div
              v-if="session.isGuest"
              class="mt-3 flex h-[42px] w-full items-center justify-center gap-1.5 rounded-xl border border-[#99F6E4] bg-brand-tint text-[13px] font-semibold text-brand-dark"
            >
              <LucideIcon name="Check" :size="16" :stroke-width="2.4" color="#0F766E" />
              Inviata come ospite
            </div>
            <button
              v-else
              class="mt-3 flex h-[42px] w-full cursor-pointer items-center justify-center gap-1.5 rounded-xl border border-[#99F6E4] bg-brand-tint text-[13px] font-semibold text-brand-dark transition-colors hover:bg-[#CCFBF1]"
              @click="store.leave(ev.id)"
            >
              <LucideIcon name="Check" :size="16" :stroke-width="2.4" color="#0F766E" />
              Partecipi
            </button>
          </template>
          <!-- not joined -->
          <button
            v-else
            class="mt-3 h-[42px] w-full cursor-pointer rounded-xl bg-brand text-[13px] font-semibold text-white transition-colors hover:bg-brand-dark"
            @click="onPartecipa(ev.id)"
          >
            Partecipa
          </button>
        </div>
      </div>
    </div>

    <OptionalLoginSheet :open="sheetOpen" @login="sheetLogin" @guest="sheetGuest" @close="sheetOpen = false" />
  </div>
</template>
